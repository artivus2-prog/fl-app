import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/bot_player.dart';
import '../services/game_server.dart';

class GameScreen extends StatefulWidget {
  final GameServer server;
  final List<String> players;
  final bool isHost;
  final String playerName;

  const GameScreen({
    super.key,
    required this.server,
    required this.players,
    required this.isHost,
    required this.playerName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late UnoGameState _gameState;
  late UnoDeck _deck;
  final BotPlayer _bot = BotPlayer();
  bool _isMyTurn = false;
  bool _gameStarted = false;
  String _direction = '➡️';
  final Set<String> _selectedCardIds = {};
  bool _multiSelectMode = false;
  bool _choosingColor = false;
  UnoCard? _pendingWildCard;
  Timer? _botTimer;
  bool _unoPressed = false;
  int _unoSecondsLeft = 10;
  Timer? _unoTimer;
  late AnimationController _pulseController;
  late AnimationController _deckGlowController;
  Timer? _lastTapTimer;
  String? _lastTappedCardId;

  bool get _isBotTurn => _gameState.currentPlayer.startsWith('Бот');
  bool get _noPlayableCards {
    if (!_isMyTurn) return false;
    return !_gameState
        .currentHand(widget.playerName)
        .any((c) => c.canPlayOn(_gameState.topCard));
  }

  @override
  void initState() {
    super.initState();
    _deck = UnoDeck(seed: 42);
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _deckGlowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    widget.server.onMessage =
        (GameMessage message) => _handleMessage(message);
    if (widget.isHost) _startGameAsHost();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _unoTimer?.cancel();
    _pulseController.dispose();
    _deckGlowController.dispose();
    super.dispose();
  }

  void _startGameAsHost() {
    Map<String, List<UnoCard>> hands = {};
    for (var player in widget.players) {
      hands[player] = _deck.drawMultiple(7);
    }
    UnoCard firstCard;
    do {
      firstCard = _deck.draw();
    } while (firstCard.type != CardType.number);

    _gameState = UnoGameState(
      drawPileCount: _deck.cards.length,
      discardPile: [firstCard],
      playerHands: hands,
      playerOrder: widget.players,
      currentPlayerIndex: 0,
    );
    _gameStarted = true;
    _updateTurn();
    _broadcastState();
  }

  void _broadcastState() {
    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.gameState,
      data: _gameState.toJson(),
    ));
  }

  void _handleMessage(GameMessage message) {
    if (!mounted) return;
    if (message.type == GameMessageType.gameState ||
        message.type == GameMessageType.startGame ||
        message.type == GameMessageType.playCard ||
        message.type == GameMessageType.drawCard) {
      setState(() {
        _gameState = UnoGameState.fromJson(message.data);
        _gameStarted = true;
        _updateTurn();
      });
    }
  }

  void _startUnoTimer() {
    _unoTimer?.cancel();
    _unoSecondsLeft = 10;
    _unoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _unoSecondsLeft--;
        if (_unoSecondsLeft <= 0) {
          timer.cancel();
          if (!_unoPressed &&
              _gameState.currentHand(widget.playerName).length == 1) {
            _applyUnoPenalty(widget.playerName);
          }
        }
      });
    });
  }

  void _updateTurn() {
    _isMyTurn = _gameState.currentPlayer == widget.playerName;
    _direction = _gameState.isClockwise ? '➡️' : '⬅️';
    _selectedCardIds.clear();
    _multiSelectMode = false;
    _choosingColor = false;
    _pendingWildCard = null;
    _unoTimer?.cancel();
    // Не сбрасываем chosenColor — он нужен для следующего хода
    _pulseController.stop();
    _deckGlowController.stop();

    if (_gameState.winner != null && mounted) {
      _showWinDialog(_gameState.winner!);
      return;
    }

    final currentHand = _gameState.currentHand(_gameState.currentPlayer);
    if (currentHand.length == 2 &&
        _gameState.currentPlayer == widget.playerName) {
      _unoPressed = false;
      _pulseController.repeat(reverse: true);
      _startUnoTimer();
    }

    if (_noPlayableCards) {
      _deckGlowController.repeat(reverse: true);
    }

    if (_isBotTurn && widget.isHost) {
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(milliseconds: 800), _botMove);
    }
  }

  void _applyClearCardEffect(CardColor color) {
    _gameState.chosenColor = null; // Сбрасываем после clear
    int totalCleared = 0;
    for (var player in _gameState.playerOrder) {
      final hand = _gameState.playerHands[player] ?? [];
      final toRemove = hand.where((c) => c.color == color).toList();
      totalCleared += toRemove.length;
      for (var card in toRemove) {
        _gameState.playerHands[player]!.removeWhere((c) => c.id == card.id);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🧹 Сброшено $totalCleared карт цвета ${_colorName(color)}!'),
          backgroundColor: _getColorForCard(color),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    for (var player in _gameState.playerOrder) {
      if (_gameState.playerHands[player]!.isEmpty &&
          _gameState.winner == null) {
        _gameState.winner = player;
      }
    }
  }

  String _colorName(CardColor color) {
    switch (color) {
      case CardColor.red:
        return 'КРАСНЫЙ';
      case CardColor.blue:
        return 'СИНИЙ';
      case CardColor.green:
        return 'ЗЕЛЁНЫЙ';
      case CardColor.yellow:
        return 'ЖЁЛТЫЙ';
      case CardColor.wild:
        return 'ДИКИЙ';
    }
  }

  void _applyUnoPenalty(String player) {
    if (_gameState.playerHands[player]!.length == 1 && !_unoPressed) {
      setState(() {
        _gameState.playerHands[player]!.addAll(_deck.drawMultiple(2));
        _gameState.drawPileCount = _deck.cards.length;
      });
      _showUnoPenaltyMessage(player);
    }
  }

  void _showUnoPenaltyMessage(String player) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(player == widget.playerName
            ? '⚠️ Вы не нажали УНО! Штраф +2 карты!'
            : '⚠️ $player не нажал УНО! Штраф +2 карты!'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _pressUno() {
    _unoTimer?.cancel();
    setState(() => _unoPressed = true);
    _pulseController.stop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ УНО!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _botMove() {
    if (!mounted || !_isBotTurn || !widget.isHost) return;
    final botName = _gameState.currentPlayer;
    final botHand = _gameState.currentHand(botName);
    final topCard = _gameState.topCard;
    final chosenColor = _gameState.chosenColor;
    final botUnoPressed = botHand.length == 2;

    // Ответ на +4
    if (_gameState.pendingResponsePlayer == botName) {
      if (_bot.shouldRespondToDraw4(botHand, chosenColor!)) {
        final draw2 = botHand.firstWhere(
            (c) => c.type == CardType.draw2 && c.color == chosenColor);
        _gameState.playerHands[botName]!.removeWhere((c) => c.id == draw2.id);
        _gameState.discardPile.add(draw2);
        final prevIndex = _gameState.isClockwise
            ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) %
                _gameState.playerCount
            : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
        _gameState.playerHands[_gameState.playerOrder[prevIndex]]!
            .addAll(_deck.drawMultiple(6));
        _gameState.pendingResponsePlayer = null;
        _gameState.nextTurn();
      } else {
        _gameState.playerHands[botName]!
            .addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 4));
        _gameState.pendingResponsePlayer = null;
        _gameState.nextTurn();
      }
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    // Выбор карты
    final chosenCard = _bot.chooseCard(botHand, topCard, chosenColor);
    if (chosenCard == null) {
      _gameState.playerHands[botName]!.add(_deck.draw());
      _gameState.drawPileCount = _deck.cards.length;
      _gameState.nextTurn();
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    // Играем карту
    _gameState.playerHands[botName]!
        .removeWhere((c) => c.id == chosenCard.id);
    _gameState.discardPile.add(chosenCard);

    if (botUnoPressed && _gameState.playerHands[botName]!.length == 1) {
      // ok
    } else if (botHand.length == 2 && !botUnoPressed) {
      _gameState.playerHands[botName]!.addAll(_deck.drawMultiple(2));
    }

    if (chosenCard.color == CardColor.wild) {
      _gameState.chosenColor = _bot.chooseColor(botHand);
    }

    // Применяем эффект
    bool skipNormalNextTurn = false;
    if (chosenCard.type == CardType.clear) {
      _applyClearCardEffect(chosenCard.color);
    } else if (chosenCard.type == CardType.wildDraw4) {
      _handleWildDraw4(chosenCard);
      skipNormalNextTurn = true; // _handleWildDraw4 сам решает
    } else {
      _applyCardEffect(chosenCard);
    }

    // Проверка победы
    if (_gameState.playerHands[botName]!.isEmpty) {
      _gameState.winner = botName;
    }

    // Переход хода
    if (!skipNormalNextTurn && _gameState.pendingResponsePlayer == null) {
      _gameState.nextTurn();
    } else if (skipNormalNextTurn &&
        _gameState.pendingResponsePlayer == null) {
      _gameState.nextTurn();
    }

    setState(() => _updateTurn());
    _broadcastState();
    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
  }

  void _onCardTap(UnoCard card) {
    if (!_isMyTurn &&
        _gameState.pendingResponsePlayer != widget.playerName) return;
    if (!_gameStarted) return;

    final isPendingDraw2 =
        _gameState.pendingResponsePlayer == widget.playerName &&
            card.type == CardType.draw2 &&
            card.color == _gameState.chosenColor;

    if (isPendingDraw2) {
      _respondToDraw4(card);
      return;
    }

    if (!_isMyTurn) return;

    final canPlay = card.canPlayOn(_gameState.topCard);

    // Двойной тап для быстрого сброса
    if (_lastTappedCardId == card.id && canPlay) {
      _lastTapTimer?.cancel();
      _lastTappedCardId = null;
      if (card.color == CardColor.wild) {
        setState(() {
          _choosingColor = true;
          _pendingWildCard = card;
        });
      } else {
        _executePlayCard([card]);
      }
      return;
    }

    _lastTappedCardId = card.id;
    _lastTapTimer?.cancel();
    _lastTapTimer = Timer(const Duration(milliseconds: 350), () {
      _lastTappedCardId = null;
    });

    if (!canPlay) return;

    if (card.color == CardColor.wild) {
      setState(() {
        _choosingColor = true;
        _pendingWildCard = card;
      });
      return;
    }

    final multiCards = _getMultiPlayableCards();
    if (multiCards.isNotEmpty && card.type == CardType.number) {
      setState(() {
        _multiSelectMode = true;
        if (_selectedCardIds.contains(card.id)) {
          _selectedCardIds.remove(card.id);
        } else {
          _selectedCardIds.add(card.id);
        }
      });
      return;
    }

    _executePlayCard([card]);
  }

  void _onColorChosen(CardColor color) {
    if (_pendingWildCard == null) return;
    setState(() {
      _choosingColor = false;
      _gameState.chosenColor = color;
    });
    _executePlayCard([_pendingWildCard!]);
  }

  void _confirmMultiPlay() {
    if (_selectedCardIds.isEmpty) return;
    _executePlayCard(_gameState
        .currentHand(widget.playerName)
        .where((c) => _selectedCardIds.contains(c.id))
        .toList());
  }

  void _executePlayCard(List<UnoCard> cards) {
    if (cards.isEmpty) return;
    final lastCard = cards.last;
    final handBefore = _gameState.currentHand(widget.playerName).length;

    // Удаляем карты из руки
    for (var card in cards) {
      _gameState.playerHands[widget.playerName]!
          .removeWhere((c) => c.id == card.id);
    }
    _gameState.discardPile.add(lastCard);

    // Проверка УНО
    if (handBefore == 2 &&
        _gameState.currentHand(widget.playerName).length == 1 &&
        !_unoPressed) {
      _applyUnoPenalty(widget.playerName);
    }

    // Применяем эффект карты
    bool skipNormalNextTurn = false;
    if (lastCard.type == CardType.clear) {
      _applyClearCardEffect(lastCard.color);
    } else if (lastCard.type == CardType.wildDraw4) {
      _handleWildDraw4(lastCard);
      skipNormalNextTurn = true;
    } else {
      _applyCardEffect(lastCard);
    }

    // Проверка победы
    if (_gameState.playerHands[widget.playerName]!.isEmpty) {
      _gameState.winner = widget.playerName;
    }

    // Переход хода: для +4 ждём ответа или передаём ход
    if (!skipNormalNextTurn && _gameState.pendingResponsePlayer == null) {
      _gameState.nextTurn();
    } else if (skipNormalNextTurn &&
        _gameState.pendingResponsePlayer == null) {
      _gameState.nextTurn();
    }

    _updateTurn();
    _broadcastState();
    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
  }

  void _handleWildDraw4(UnoCard wildCard) {
    final nextIndex = _gameState.isClockwise
        ? (_gameState.currentPlayerIndex + 1) % _gameState.playerCount
        : (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) %
            _gameState.playerCount;
    final nextPlayer = _gameState.playerOrder[nextIndex];
    final nextHand = _gameState.playerHands[nextPlayer] ?? [];
    final chosenColor = _gameState.chosenColor;
    if (chosenColor == null) return;

    final hasDraw2 = nextHand
        .any((c) => c.type == CardType.draw2 && c.color == chosenColor);
    final hasOnlyDraw2 = hasDraw2 && nextHand.length == 1;

    if (hasOnlyDraw2) {
      // Победа ответившего
      _gameState.winner = nextPlayer;
      _gameState.playerHands[nextPlayer]!.clear();
      _gameState.pendingResponsePlayer = null;
      return;
    }

    if (hasDraw2) {
      // Ждём ответа
      _gameState.pendingResponsePlayer = nextPlayer;
      _gameState.pendingDrawCount = 6;
      return;
    }

    // Обычный +4: следующий берёт 4 карты
    _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(4));
    _gameState.pendingResponsePlayer = null;
  }

  void _respondToDraw4(UnoCard draw2Card) {
    _gameState.playerHands[widget.playerName]!
        .removeWhere((c) => c.id == draw2Card.id);
    _gameState.discardPile.add(draw2Card);

    final prevIndex = _gameState.isClockwise
        ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) %
            _gameState.playerCount
        : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
    _gameState.playerHands[_gameState.playerOrder[prevIndex]]!
        .addAll(_deck.drawMultiple(6));

    _gameState.pendingResponsePlayer = null;
    _gameState.nextTurn();
    _updateTurn();
    _broadcastState();
  }

  void _applyCardEffect(UnoCard card) {
    // Сбрасываем выбранный цвет при игре обычной карты
    _gameState.chosenColor = null;
    switch (card.type) {
      case CardType.skip:
        _gameState.nextTurn();
        break;
      case CardType.reverse:
        _gameState.isClockwise = !_gameState.isClockwise;
        if (_gameState.playerCount == 2) _gameState.nextTurn();
        break;
      case CardType.draw2:
        _gameState.nextTurn();
        _gameState.playerHands[_gameState.currentPlayer]!
            .addAll(_deck.drawMultiple(2));
        break;
      default:
        break;
    }
  }

  void _drawCard() {
    if (!_isMyTurn &&
        _gameState.pendingResponsePlayer != widget.playerName) return;
    if (!_gameStarted) return;

    if (_gameState.pendingResponsePlayer == widget.playerName) {
      // Не ответил на +4 — берёт 6 карт
      _gameState.playerHands[widget.playerName]!
          .addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 6));
      _gameState.pendingResponsePlayer = null;
    } else {
      _gameState.playerHands[widget.playerName]!.add(_deck.draw());
    }

    _gameState.drawPileCount = _deck.cards.length;
    _gameState.nextTurn();
    _updateTurn();
    _broadcastState();
  }

  List<UnoCard> _getMultiPlayableCards() {
    if (!_isMyTurn) return [];
    final hand = _gameState.currentHand(widget.playerName);
    final topCard = _gameState.topCard;
    Map<String, List<UnoCard>> groups = {};
    for (var card in hand) {
      if (card.type == CardType.number && card.canPlayOn(topCard)) {
        groups.putIfAbsent('${card.number}', () => []);
        groups['${card.number}']!.add(card);
      }
    }
    for (var group in groups.values) {
      if (group.length >= 2) return group;
    }
    return [];
  }

  void _showWinDialog(String winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(children: [
          const Text('🎉', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Text(winner == widget.playerName ? 'Вы победили!' : 'Победа!',
              style: const TextStyle(color: Colors.white))
        ]),
        content: Text(
            winner == widget.playerName
                ? 'Отличная игра! Вы выиграли!'
                : '$winner выиграл игру!',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.server.stop();
                Navigator.pop(context);
              },
              child:
                  const Text('В меню', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.isHost) {
                setState(() {
                  _deck = UnoDeck(seed: Random().nextInt(99999));
                  _startGameAsHost();
                });
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF)),
            child: const Text('Играть снова'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    if (!_choosingColor) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(children: [
          Icon(Icons.palette, color: Colors.purple),
          SizedBox(width: 12),
          Text('Выберите цвет', style: TextStyle(color: Colors.white))
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Дикая карта — выберите следующий цвет:',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _colorButton(CardColor.red, 'Красный', ctx),
            _colorButton(CardColor.blue, 'Синий', ctx),
            _colorButton(CardColor.green, 'Зелёный', ctx),
            _colorButton(CardColor.yellow, 'Жёлтый', ctx),
          ]),
        ]),
      ),
    );
  }

  Widget _colorButton(CardColor color, String label, BuildContext ctx) {
    Color c;
    switch (color) {
      case CardColor.red: c = Colors.red; break;
      case CardColor.blue: c = Colors.blue; break;
      case CardColor.green: c = Colors.green; break;
      case CardColor.yellow: c = Colors.amber; break;
      default: c = Colors.grey;
    }
    return GestureDetector(
      onTap: () { Navigator.pop(ctx); _onColorChosen(color); },
      child: Column(children: [
        Container(width: 50, height: 50,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)])),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_choosingColor) WidgetsBinding.instance.addPostFrameCallback((_) => _showColorPicker());
    if (!_gameStarted) {
      return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: Color(0xFF7C4DFF)),
            SizedBox(height: 24),
            Text('Ожидание начала игры...', style: TextStyle(color: Colors.white, fontSize: 18))
          ])));
    }

    final myHand = _gameState.currentHand(widget.playerName);
    final isPendingResponse = _gameState.pendingResponsePlayer == widget.playerName;
    final showUnoButton = myHand.length == 2 && _isMyTurn && !_unoPressed;
    final canDraw = _isMyTurn || isPendingResponse;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Уно ', style: TextStyle(color: Colors.white)),
          Text(_direction, style: const TextStyle(fontSize: 20))
        ]),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.white70),
            onPressed: () { widget.server.stop(); Navigator.pop(context); }),
        actions: [
          if (_isBotTurn)
            const Padding(padding: EdgeInsets.only(right: 8),
                child: Chip(label: Text('БОТ ДУМАЕТ...', style: TextStyle(color: Colors.white, fontSize: 11)),
                    backgroundColor: Color(0xFF7C4DFF),
                    avatar: SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
          if (isPendingResponse)
            const Padding(padding: EdgeInsets.only(right: 8),
                child: Chip(label: Text('ОТВЕТЬТЕ!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange)),
          if (_isMyTurn && !isPendingResponse)
            const Padding(padding: EdgeInsets.only(right: 8),
                child: Chip(label: Text('ВАШ ХОД', style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Color(0xFF00E676), avatar: Icon(Icons.play_arrow, size: 16))),
        ],
      ),
      body: Column(children: [
        // УНО кнопка
        if (showUnoButton || (_unoPressed && myHand.length == 1))
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Container(
              padding: const EdgeInsets.all(12), margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _unoPressed ? [Colors.green, Colors.greenAccent] : [Colors.red, Colors.deepOrange]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3 + _pulseController.value * 0.3),
                    blurRadius: 12 + _pulseController.value * 10)],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (!_unoPressed && myHand.length == 2) ...[
                  const Icon(Icons.warning, color: Colors.white, size: 28), const SizedBox(width: 12),
                  Expanded(child: Column(children: [
                    const Text('НАЖМИТЕ УНО!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                    Text('$_unoSecondsLeft сек до штрафа', style: const TextStyle(color: Colors.white70, fontSize: 14))
                  ])), const SizedBox(width: 12),
                  SizedBox(height: 48,
                      child: ElevatedButton(
                          onPressed: _pressUno,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(horizontal: 24)),
                          child: const Text('УНО!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)))),
                ] else ...[
                  const Icon(Icons.check_circle, color: Colors.white, size: 24), const SizedBox(width: 8),
                  const Text('УНО принято!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ]),
            ),
          ),

        // Верхняя карта + колода
        Expanded(flex: 2, child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: canDraw ? _drawCard : null,
            child: AnimatedBuilder(
              animation: _deckGlowController,
              builder: (context, child) {
                final glow = _noPlayableCards ? _deckGlowController.value : 0.0;
                return Container(
                  width: 80, height: 115,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF333333)]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color.lerp(Colors.white.withOpacity(0.3), Colors.yellow, glow)!, width: 2 + glow * 2),
                    boxShadow: [
                      BoxShadow(color: Colors.yellow.withOpacity(glow * 0.6), blurRadius: 10 + glow * 15, spreadRadius: glow * 4),
                      BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10, offset: const Offset(3, 4)),
                    ],
                  ),
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('УНО', style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Container(width: 40, height: 3,
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue]),
                            borderRadius: BorderRadius.all(Radius.circular(2)))),
                  ])),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          _buildCardWidget(_gameState.topCard, big: true),
        ]))),

        // Полоска игроков
        Container(height: 50, margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: widget.players.length,
                itemBuilder: (context, index) {
                  final player = widget.players[index];
                  final isCurrent = player == _gameState.currentPlayer;
                  final cardCount = _gameState.playerHands[player]?.length ?? 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: isCurrent ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: isCurrent ? Border.all(color: Colors.greenAccent, width: 2) : Border.all(color: Colors.white12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(player.startsWith('Бот') ? Icons.computer : Icons.person, size: 14,
                          color: player == widget.playerName ? Colors.amber : Colors.white70),
                      const SizedBox(width: 4),
                      Text(player, style: TextStyle(fontSize: 11, color: Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      const SizedBox(width: 4),
                      Text('$cardCount🃏', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                    ]),
                  );
                })),

        // Подсказки
        if (_multiSelectMode)
          Container(padding: const EdgeInsets.all(8), color: Colors.amber.withOpacity(0.2),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.touch_app, size: 18, color: Colors.amber), SizedBox(width: 8),
                Text('Нажмите на карты чтобы выбрать для сброса', style: TextStyle(color: Colors.amber, fontSize: 13)),
              ])),
        if (isPendingResponse)
          Container(padding: const EdgeInsets.all(8), color: Colors.orange.withOpacity(0.2),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.warning, size: 18, color: Colors.orange), SizedBox(width: 8),
                Text('Ответьте своей +2 или возьмите 6 карт!', style: TextStyle(color: Colors.orange, fontSize: 13)),
              ])),
        if (_noPlayableCards && _isMyTurn)
          Container(padding: const EdgeInsets.all(8), color: Colors.yellow.withOpacity(0.15),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.touch_app, size: 18, color: Colors.yellow), SizedBox(width: 8),
                Text('Нет доступных карт — нажмите на колоду', style: TextStyle(color: Colors.yellow, fontSize: 13)),
              ])),

        const SizedBox(height: 4),

        // Кнопка мультисброса
        if (_multiSelectMode && _selectedCardIds.length >= 2)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _confirmMultiPlay,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Сбросить выбранные карты', style: TextStyle(fontWeight: FontWeight.bold))))),

        // Карты игрока — ВЕЕРОМ
        Expanded(flex: 3,
            child: myHand.isEmpty
                ? const Center(child: Text('У вас нет карт!', style: TextStyle(fontSize: 18, color: Colors.white38)))
                : Center(child: LayoutBuilder(builder: (context, constraints) {
                    final cardWidth = 75.0;
                    final cardHeight = 110.0;
                    final count = myHand.length;
                    final fanAngle = (count * 4.0).clamp(8.0, 35.0) * (3.14159 / 180);
                    final radius = (count * 4.0 + 180).clamp(200.0, 400.0);

                    return GestureDetector(
                      onTap: () { if (_multiSelectMode) setState(() { _selectedCardIds.clear(); _multiSelectMode = false; }); },
                      child: SizedBox(width: constraints.maxWidth, height: cardHeight + 50,
                          child: Stack(clipBehavior: Clip.none, children: List.generate(count, (index) {
                            final card = myHand[index];
                            final canPlay = _isMyTurn && card.canPlayOn(_gameState.topCard);
                            final isPendingDraw2 = isPendingResponse &&
                                card.type == CardType.draw2 && card.color == _gameState.chosenColor;
                            final isSelected = _selectedCardIds.contains(card.id);
                            final canTap = canPlay || isPendingDraw2;

                            final double angle;
                            final double offsetY;
                            if (count <= 3) {
                              angle = (index - (count - 1) / 2) * fanAngle;
                              offsetY = 0;
                            } else {
                              final normalizedIndex = (index - (count - 1) / 2) / ((count - 1) / 2);
                              angle = normalizedIndex * fanAngle * 3;
                              offsetY = (index - (count - 1) / 2).abs() * 3;
                            }

                            final centerX = constraints.maxWidth / 2;
                            final dx = sin(angle) * radius;

                            return Positioned(
                              left: centerX - cardWidth / 2 + dx,
                              bottom: 0 + offsetY,
                              child: Transform.rotate(
                                angle: angle,
                                child: GestureDetector(
                                  onTap: () => _onCardTap(card),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: EdgeInsets.only(top: (canTap || isPendingDraw2) ? 0 : 18),
                                    decoration: isSelected
                                        ? BoxDecoration(borderRadius: BorderRadius.circular(16),
                                            boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.8), blurRadius: 16, spreadRadius: 3)])
                                        : null,
                                    child: Opacity(
                                      opacity: (canTap || isPendingDraw2) ? 1.0 : 0.55,
                                      child: Stack(children: [
                                        _buildCardWidget(card),
                                        if (isPendingDraw2)
                                          Positioned(top: -5, right: -5,
                                              child: Container(padding: const EdgeInsets.all(4),
                                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                                  child: const Icon(Icons.reply, size: 16, color: Colors.white))),
                                        if (isSelected)
                                          const Positioned(top: -5, left: -5,
                                              child: Icon(Icons.check_circle, color: Colors.amber, size: 22)),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }))),
                    );
                  }))),
      ]),
    );
  }

  Widget _buildCardWidget(UnoCard card, {bool big = false}) {
    final w = big ? 105.0 : 75.0;
    final h = big ? 155.0 : 110.0;
    final isWild = card.color == CardColor.wild;
    final isClear = card.type == CardType.clear;
    final bgColor = card.displayColor;
    final txtColor = (card.color == CardColor.yellow) ? Colors.black : Colors.white;

    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8, offset: const Offset(2, 4))],
      ),
      child: Stack(children: [
        if (!isWild && !isClear)
          Center(child: Transform.rotate(angle: -0.3,
              child: Container(width: w * 0.7, height: h * 0.55,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(40))))),
        Center(child: Text(card.displayText,
            style: TextStyle(fontSize: big ? 48 : 34, fontWeight: FontWeight.w900, color: txtColor,
                shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(1, 2))]))),
        if (card.type == CardType.number)
          Positioned(top: 6, left: 10,
              child: Text('${card.number}', style: TextStyle(fontSize: big ? 20 : 14, fontWeight: FontWeight.w900, color: txtColor))),
        if (isWild)
          Positioned(bottom: 0, left: 4, right: 4,
              child: Container(height: 5,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue]),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))))),
      ]),
    );
  }

  Color _getColorForCard(CardColor color) {
    switch (color) {
      case CardColor.red: return Colors.red;
      case CardColor.blue: return Colors.blue;
      case CardColor.green: return Colors.green;
      case CardColor.yellow: return Colors.amber;
      case CardColor.wild: return Colors.purple;
    }
  }
}
