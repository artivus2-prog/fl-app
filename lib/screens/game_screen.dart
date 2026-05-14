import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/bot_player.dart';
import '../services/game_server.dart';
import 'settings_screen.dart';

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
  Color _backgroundColor = const Color(0xFF0A0A1A);

  bool get _isBotTurn => _gameState.currentPlayer.startsWith('Бот');
  bool get _noPlayableCards {
    if (!_isMyTurn && _gameState.pendingResponsePlayer != widget.playerName) return false;
    return !_gameState.currentHand(widget.playerName)
        .any((c) => c.canPlayOn(_gameState.topCard, chosenColor: _gameState.chosenColor));
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _deck = UnoDeck(seed: 42);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _deckGlowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    widget.server.onMessage = (GameMessage message) => _handleMessage(message);
    if (widget.isHost) _startGameAsHost();
    _loadBackground();
  }

  Future<void> _loadBackground() async {
    setState(() => _backgroundColor = SettingsScreenState.backgroundColor);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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
    do { firstCard = _deck.draw(); } while (firstCard.type != CardType.number);
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
    widget.server.broadcastAll(GameMessage(type: GameMessageType.gameState, data: _gameState.toJson()));
  }

  void _handleMessage(GameMessage message) {
    if (!mounted) return;
    setState(() {
      _gameState = UnoGameState.fromJson(message.data);
      _gameStarted = true;
      _updateTurn();
    });
  }

  void _startUnoTimer() {
    _unoTimer?.cancel();
    _unoSecondsLeft = 10;
    _unoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _unoSecondsLeft--;
        if (_unoSecondsLeft <= 0) {
          timer.cancel();
          if (!_unoPressed && _gameState.currentHand(widget.playerName).length == 1) {
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
    _pulseController.stop();
    _deckGlowController.stop();
    if (_gameState.winner != null && mounted) { _showWinDialog(_gameState.winner!); return; }
    final top = _gameState.discardPile.isNotEmpty ? _gameState.discardPile.last : null;
    if (top == null || top.color != CardColor.wild) {
      _gameState.chosenColor = null;
    }
    final currentHand = _gameState.currentHand(_gameState.currentPlayer);
    if (currentHand.length == 2 && _gameState.currentPlayer == widget.playerName) {
      _unoPressed = false;
      _pulseController.repeat(reverse: true);
      _startUnoTimer();
    }
    if (_noPlayableCards && _gameState.pendingResponsePlayer != widget.playerName) {
      _deckGlowController.repeat(reverse: true);
    }
    if (_isBotTurn && widget.isHost) {
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(milliseconds: 800), _botMove);
    }
  }

  // ========== ЦЕПОЧКИ ОТВЕТОВ ==========
  
  // Игрок кидает +4/+8
  void _throwWildDraw(UnoCard card) {
    final isDraw8 = card.type == CardType.wildDraw8;
    final baseDraw = isDraw8 ? 8 : 4;
    
    // Находим следующего игрока
    final nextIndex = _gameState.isClockwise
        ? (_gameState.currentPlayerIndex + 1) % _gameState.playerCount
        : (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount;
    final nextPlayer = _gameState.playerOrder[nextIndex];
    final nextHand = _gameState.playerHands[nextPlayer] ?? [];
    final chosenColor = _gameState.chosenColor;
    
    if (chosenColor == null) return;
    
    // Проверяем, может ли ответить
    final canRespond = nextHand.any((c) =>
      (c.type == CardType.draw2 || c.type == CardType.wildDraw4 || c.type == CardType.wildDraw8) &&
      c.color == chosenColor);
    final onlyOneCard = canRespond && nextHand.length == 1;
    
    if (onlyOneCard) {
      // Победа!
      _gameState.winner = nextPlayer;
      _gameState.playerHands[nextPlayer]!.clear();
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      return;
    }
    
    // Накапливаем штраф
    _gameState.pendingDrawCount = (_gameState.pendingDrawCount ?? 0) + baseDraw + 2;
    
    if (canRespond) {
      // Ждём ответа от следующего
      _gameState.pendingResponsePlayer = nextPlayer;
    } else {
      // Не может ответить — забирает всё
      _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(_gameState.pendingDrawCount));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
    }
  }

  // Игрок отвечает на pending
  void _respondToPending(UnoCard card) {
    _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
    _gameState.discardPile.add(card);
    
    if (card.type == CardType.draw2) {
      // Ответ +2 — завершаем цепочку, ПРЕДЫДУЩИЙ игрок забирает всё
      final prevIndex = _gameState.isClockwise
          ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount
          : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
      final prevPlayer = _gameState.playerOrder[prevIndex];
      _gameState.playerHands[prevPlayer]!.addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 6));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      // Ход переходит к следующему после ответившего
      _gameState.nextTurn();
    } else {
      // Ответ +4 или +8 — продолжаем цепочку
      _throwWildDraw(card);
      // Ход переходит к следующему
      _gameState.nextTurn();
    }
    
    _updateTurn();
    _broadcastState();
  }

  // ========== ОСТАЛЬНАЯ ЛОГИКА ==========

  void _applyClearCardEffect(CardColor color) {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🧹 Сброшено $totalCleared карт цвета ${_colorName(color)}!'),
        backgroundColor: _getColorForCard(color),
        duration: const Duration(seconds: 3),
      ));
    }
    for (var player in _gameState.playerOrder) {
      if (_gameState.playerHands[player]!.isEmpty && _gameState.winner == null) {
        _gameState.winner = player;
      }
    }
  }

  String _colorName(CardColor color) {
    switch (color) {
      case CardColor.red: return 'КРАСНЫЙ';
      case CardColor.blue: return 'СИНИЙ';
      case CardColor.green: return 'ЗЕЛЁНЫЙ';
      case CardColor.yellow: return 'ЖЁЛТЫЙ';
      case CardColor.wild: return 'ДИКИЙ';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(player == widget.playerName ? '⚠️ Вы не нажали УНО! Штраф +2 карты!' : '⚠️ $player не нажал УНО! Штраф +2 карты!'),
      backgroundColor: Colors.red, duration: const Duration(seconds: 3),
    ));
  }

  void _pressUno() {
    _unoTimer?.cancel();
    setState(() => _unoPressed = true);
    _pulseController.stop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ УНО!'), backgroundColor: Colors.green, duration: Duration(seconds: 1),
    ));
  }

  void _botMove() {
    if (!mounted || !_isBotTurn || !widget.isHost) return;
    final botName = _gameState.currentPlayer;
    final botHand = _gameState.currentHand(botName);
    final topCard = _gameState.topCard;
    final chosenColor = _gameState.chosenColor;
    final botUnoPressed = botHand.length == 2;

    // Ответ на pending
    if (_gameState.pendingResponsePlayer == botName) {
      if (_bot.shouldRespondToDraw4(botHand, _gameState.chosenColor)) {
        final responseCard = _bot.chooseResponseCard(botHand, _gameState.chosenColor!);
        if (responseCard != null) {
          _gameState.playerHands[botName]!.removeWhere((c) => c.id == responseCard.id);
          _gameState.discardPile.add(responseCard);
          if (responseCard.type == CardType.draw2) {
            final prevIndex = _gameState.isClockwise
                ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount
                : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
            _gameState.playerHands[_gameState.playerOrder[prevIndex]]!.addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 6));
            _gameState.pendingResponsePlayer = null;
            _gameState.pendingDrawCount = 0;
            _gameState.nextTurn();
          } else {
            _throwWildDraw(responseCard);
            _gameState.nextTurn();
          }
          setState(() => _updateTurn());
          _broadcastState();
          return;
        }
      }
      // Не может ответить — берёт все карты
      _gameState.playerHands[botName]!.addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 4));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      _gameState.nextTurn();
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    final chosenCard = _bot.chooseCard(botHand, topCard, chosenColor);
    if (chosenCard == null) {
      _gameState.playerHands[botName]!.add(_deck.draw());
      _gameState.drawPileCount = _deck.cards.length;
      _gameState.nextTurn();
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    _gameState.playerHands[botName]!.removeWhere((c) => c.id == chosenCard.id);
    _gameState.discardPile.add(chosenCard);

    if (botUnoPressed && _gameState.playerHands[botName]!.length == 1) {
      // ok
    } else if (botHand.length == 2 && !botUnoPressed) {
      _gameState.playerHands[botName]!.addAll(_deck.drawMultiple(2));
    }

    if (chosenCard.color == CardColor.wild) {
      _gameState.chosenColor = _bot.chooseColor(botHand);
    }

    if (chosenCard.type == CardType.clear) {
      _applyClearCardEffect(chosenCard.color);
      _gameState.nextTurn();
    } else if (chosenCard.type == CardType.wildDraw4 || chosenCard.type == CardType.wildDraw8) {
      _throwWildDraw(chosenCard);
      if (_gameState.pendingResponsePlayer == null) _gameState.nextTurn();
    } else {
      _applyCardEffect(chosenCard);
      _gameState.nextTurn();
    }

    if (_gameState.playerHands[botName]!.isEmpty) _gameState.winner = botName;
    setState(() => _updateTurn());
    _broadcastState();
    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
  }

  void _onCardTap(UnoCard card) {
    if (!_gameStarted) return;
    final isMyPending = _gameState.pendingResponsePlayer == widget.playerName;
    final canRespond = isMyPending && 
        (card.type == CardType.draw2 || card.type == CardType.wildDraw4 || card.type == CardType.wildDraw8) &&
        card.color == _gameState.chosenColor;

    if (canRespond) { _respondToPending(card); return; }
    if (!_isMyTurn) return;

    final canPlay = card.canPlayOn(_gameState.topCard, chosenColor: _gameState.chosenColor);

    if (_lastTappedCardId == card.id && canPlay) {
      _lastTapTimer?.cancel(); _lastTappedCardId = null;
      if (card.color == CardColor.wild) {
        setState(() { _choosingColor = true; _pendingWildCard = card; });
      } else {
        _executePlayCard([card]);
      }
      return;
    }
    _lastTappedCardId = card.id;
    _lastTapTimer?.cancel();
    _lastTapTimer = Timer(const Duration(milliseconds: 350), () { _lastTappedCardId = null; });
    if (!canPlay) return;
    if (card.color == CardColor.wild) {
      setState(() { _choosingColor = true; _pendingWildCard = card; });
      return;
    }
    final multiCards = _getMultiPlayableCards();
    if (multiCards.isNotEmpty && card.type == CardType.number) {
      setState(() {
        _multiSelectMode = true;
        _selectedCardIds.contains(card.id) ? _selectedCardIds.remove(card.id) : _selectedCardIds.add(card.id);
      });
      return;
    }
    _executePlayCard([card]);
  }

  void _onColorChosen(CardColor color) {
    if (_pendingWildCard == null) return;
    setState(() { _choosingColor = false; _gameState.chosenColor = color; });
    _executePlayCard([_pendingWildCard!]);
  }

  void _confirmMultiPlay() {
    if (_selectedCardIds.isEmpty) return;
    _executePlayCard(_gameState.currentHand(widget.playerName).where((c) => _selectedCardIds.contains(c.id)).toList());
  }

  void _executePlayCard(List<UnoCard> cards) {
    if (cards.isEmpty) return;
    final lastCard = cards.last;
    final handBefore = _gameState.currentHand(widget.playerName).length;
    for (var card in cards) {
      _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
    }
    _gameState.discardPile.add(lastCard);
    if (handBefore == 2 && _gameState.currentHand(widget.playerName).length == 1 && !_unoPressed) {
      _applyUnoPenalty(widget.playerName);
    }
    if (lastCard.type == CardType.clear) {
      _applyClearCardEffect(lastCard.color);
      _gameState.nextTurn();
    } else if (lastCard.type == CardType.wildDraw4 || lastCard.type == CardType.wildDraw8) {
      _throwWildDraw(lastCard);
      if (_gameState.pendingResponsePlayer == null) _gameState.nextTurn();
    } else {
      _applyCardEffect(lastCard);
      _gameState.nextTurn();
    }
    if (_gameState.playerHands[widget.playerName]!.isEmpty) {
      _gameState.winner = widget.playerName;
    }
    _updateTurn();
    _broadcastState();
    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
  }

  void _applyCardEffect(UnoCard card) {
    switch (card.type) {
      case CardType.skip: _gameState.nextTurn(); break;
      case CardType.reverse:
        _gameState.isClockwise = !_gameState.isClockwise;
        if (_gameState.playerCount == 2) _gameState.nextTurn();
        break;
      case CardType.draw2:
        _gameState.nextTurn();
        _gameState.playerHands[_gameState.currentPlayer]!.addAll(_deck.drawMultiple(2));
        break;
      default: break;
    }
  }

  void _drawCard() {
    if (!_isMyTurn && _gameState.pendingResponsePlayer != widget.playerName) return;
    if (!_gameStarted) return;
    if (_gameState.pendingResponsePlayer == widget.playerName) {
      // Сдаёмся — берём все накопленные карты
      _gameState.playerHands[widget.playerName]!.addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 4));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
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
      if (card.type == CardType.number && card.canPlayOn(topCard, chosenColor: _gameState.chosenColor)) {
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
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(children: [const Text('🎉', style: TextStyle(fontSize: 32)), const SizedBox(width: 12),
          Text(winner == widget.playerName ? 'Вы победили!' : 'Победа!', style: const TextStyle(color: Colors.white))]),
        content: Text(winner == widget.playerName ? 'Отличная игра! Вы выиграли!' : '$winner выиграл игру!',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); widget.server.stop(); Navigator.pop(context); },
              child: const Text('В меню', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); if (widget.isHost) { setState(() {
            _deck = UnoDeck(seed: Random().nextInt(99999)); _startGameAsHost(); }); } },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
            child: const Text('Играть снова')),
        ],
      ),
    );
  }

  void _showColorPicker() {
    if (!_choosingColor) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(children: [Icon(Icons.palette, color: Colors.purple), SizedBox(width: 12),
          Text('Выберите цвет', style: TextStyle(color: Colors.white))]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Дикая карта — выберите следующий цвет:', style: TextStyle(color: Colors.grey)),
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
    switch (color) { case CardColor.red: c = Colors.red; break; case CardColor.blue: c = Colors.blue; break; case CardColor.green: c = Colors.green; break; case CardColor.yellow: c = Colors.amber; break; default: c = Colors.grey; }
    return GestureDetector(
      onTap: () { Navigator.pop(ctx); _onColorChosen(color); },
      child: Column(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)])),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    if (_choosingColor) WidgetsBinding.instance.addPostFrameCallback((_) => _showColorPicker());
    if (!_gameStarted) {
      return Scaffold(backgroundColor: _backgroundColor,
          body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: Color(0xFF7C4DFF)), SizedBox(height: 24),
            Text('Ожидание начала игры...', style: TextStyle(color: Colors.white, fontSize: 18)),
          ])));
    }
    final myHand = _gameState.currentHand(widget.playerName);
    final isPending = _gameState.pendingResponsePlayer == widget.playerName;
    final showUnoButton = myHand.length == 2 && _isMyTurn && !_unoPressed;
    final canDraw = _isMyTurn || isPending;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(isPending),
      body: Column(children: [
        if (showUnoButton || (_unoPressed && myHand.length == 1)) _buildUnoButton(myHand),
        if (isPending && _gameState.pendingDrawCount != null)
          _buildChainInfo(),
        _buildTopCards(canDraw),
        _buildPlayerBar(),
        if (_multiSelectMode) _buildHint('Нажмите на карты чтобы выбрать для сброса', Colors.amber, Icons.touch_app),
        if (isPending) _buildHint('Ответьте +2/+4/+8 выбранного цвета или нажмите колоду чтобы взять ${_gameState.pendingDrawCount ?? 0} карт', Colors.orange, Icons.warning),
        if (_noPlayableCards && !isPending) _buildHint('Нет доступных карт — нажмите на колоду', Colors.yellow, Icons.touch_app),
        const SizedBox(height: 4),
        if (_multiSelectMode && _selectedCardIds.length >= 2)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(onPressed: _confirmMultiPlay,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Сбросить выбранные карты', style: TextStyle(fontWeight: FontWeight.bold))))),
        _buildPlayerHand(myHand, isPending),
      ]),
    );
  }

  Widget _buildChainInfo() {
    return Container(
      padding: const EdgeInsets.all(8), margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
      child: Text('🔥 На кону ${_gameState.pendingDrawCount} карт!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
    );
  }

  AppBar _buildAppBar(bool isPending) {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0,
      title: Row(mainAxisSize: MainAxisSize.min, children: [const Text('Уно ', style: TextStyle(color: Colors.white)), Text(_direction, style: const TextStyle(fontSize: 20))]),
      centerTitle: true,
      leading: IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.white70), onPressed: () { widget.server.stop(); Navigator.pop(context); }),
      actions: [
        if (_isBotTurn) _buildChip('БОТ ДУМАЕТ...', const Color(0xFF7C4DFF), true),
        if (isPending) _buildChip('ОТВЕТЬТЕ!', Colors.orange, false),
        if (_isMyTurn && !isPending) _buildChip('ВАШ ХОД', const Color(0xFF00E676), false),
      ],
    );
  }

  Widget _buildChip(String text, Color color, bool spinner) {
    return Padding(padding: const EdgeInsets.only(right: 8), child: Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: color,
      avatar: spinner ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : null,
    ));
  }

  Widget _buildUnoButton(List<UnoCard> myHand) {
    return AnimatedBuilder(animation: _pulseController, builder: (context, child) => Container(
      padding: const EdgeInsets.all(12), margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _unoPressed ? [Colors.green, Colors.greenAccent] : [Colors.red, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3 + _pulseController.value * 0.3), blurRadius: 12 + _pulseController.value * 10)],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (!_unoPressed && myHand.length == 2) ...[
          const Icon(Icons.warning, color: Colors.white, size: 28), const SizedBox(width: 12),
          Expanded(child: Column(children: [
            const Text('НАЖМИТЕ УНО!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
            Text('$_unoSecondsLeft сек до штрафа', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ])), const SizedBox(width: 12),
          SizedBox(height: 48, child: ElevatedButton(onPressed: _pressUno,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 24)),
            child: const Text('УНО!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)))),
        ] else ...[
          const Icon(Icons.check_circle, color: Colors.white, size: 24), const SizedBox(width: 8),
          const Text('УНО принято!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ]),
    ));
  }

  Widget _buildTopCards(bool canDraw) {
    return Expanded(flex: 2, child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      GestureDetector(onTap: canDraw ? _drawCard : null,
        child: AnimatedBuilder(animation: _deckGlowController, builder: (context, child) {
          final glow = (_noPlayableCards && !_gameState.pendingResponsePlayer!.isNotEmpty) ? _deckGlowController.value : 0.0;
          return Container(
            width: 80, height: 115,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF333333)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color.lerp(Colors.white.withOpacity(0.3), Colors.yellow, glow)!, width: 2 + glow * 2),
              boxShadow: [BoxShadow(color: Colors.yellow.withOpacity(glow * 0.6), blurRadius: 10 + glow * 15, spreadRadius: glow * 4),
                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10, offset: const Offset(3, 4))],
            ),
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('УНО', style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
              const SizedBox(height: 4),
              Container(width: 40, height: 3, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue]), borderRadius: BorderRadius.all(Radius.circular(2)))),
            ])),
          );
        }),
      ),
      const SizedBox(width: 24),
      _buildCardWidget(_gameState.topCard, big: true),
    ])));
  }

  Widget _buildPlayerBar() {
    return Container(height: 50, margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: widget.players.length, itemBuilder: (context, index) {
        final player = widget.players[index];
        final isCurrent = player == _gameState.currentPlayer;
        final cardCount = _gameState.playerHands[player]?.length ?? 0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: isCurrent ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10), border: isCurrent ? Border.all(color: Colors.greenAccent, width: 2) : Border.all(color: Colors.white12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(player.startsWith('Бот') ? Icons.computer : Icons.person, size: 14, color: player == widget.playerName ? Colors.amber : Colors.white70),
            const SizedBox(width: 4),
            Text(player, style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 4),
            Text('$cardCount🃏', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
        );
      }),
    );
  }

  Widget _buildHint(String text, Color color, IconData icon) {
    return Container(padding: const EdgeInsets.all(8), color: color.withOpacity(0.2),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: color), const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color, fontSize: 13)),
      ]));
  }

  Widget _buildPlayerHand(List<UnoCard> myHand, bool isPending) {
    if (myHand.isEmpty) return const Expanded(flex: 3, child: Center(child: Text('У вас нет карт!', style: TextStyle(fontSize: 18, color: Colors.white38))));
    final totalCards = myHand.length;
    double overlapPx = 0;
    if (totalCards > 7) {
      final extraCards = totalCards - 7;
      final reductionPercent = (extraCards * 3.0).clamp(0.0, 80.0);
      overlapPx = 75.0 * (reductionPercent / 100.0);
    }
    return Expanded(flex: 3, child: GestureDetector(
      onTap: () { if (_multiSelectMode) setState(() { _selectedCardIds.clear(); _multiSelectMode = false; }); },
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(height: 130,
          child: totalCards <= 7
              ? Row(mainAxisSize: MainAxisSize.min, children: List.generate(totalCards, (i) => _buildCardItem(myHand[i], i, 0, isPending))))
              : Stack(children: List.generate(totalCards, (i) => Positioned(left: i * overlapPx, top: _cardTopOffset(myHand[i], isPending), child: _buildCardItem(myHand[i], i, 0, isPending))))),
      ),
    ));
  }

  double _cardTopOffset(UnoCard card, bool isPending) {
    final canPlay = _isMyTurn && card.canPlayOn(_gameState.topCard, chosenColor: _gameState.chosenColor);
    final canRespond = isPending && (card.type == CardType.draw2 || card.type == CardType.wildDraw4 || card.type == CardType.wildDraw8) && card.color == _gameState.chosenColor;
    return (canPlay || canRespond) ? 0.0 : 18.0;
  }

  Widget _buildCardItem(UnoCard card, int index, double extraTop, bool isPending) {
    final canPlay = _isMyTurn && card.canPlayOn(_gameState.topCard, chosenColor: _gameState.chosenColor);
    final canRespond = isPending && (card.type == CardType.draw2 || card.type == CardType.wildDraw4 || card.type == CardType.wildDraw8) && card.color == _gameState.chosenColor;
    final isSelected = _selectedCardIds.contains(card.id);
    final canTap = canPlay || canRespond;
    return GestureDetector(
      onTap: () => _onCardTap(card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(top: (canTap) ? 0.0 : 18.0),
        decoration: isSelected ? BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.8), blurRadius: 16, spreadRadius: 3)]) : null,
        child: Opacity(opacity: canTap ? 1.0 : 0.85, child: Stack(children: [
          _buildCardWidget(card),
          if (canRespond) Positioned(top: -5, right: -5, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.reply, size: 16, color: Colors.white))),
          if (isSelected) const Positioned(top: -5, left: -5, child: Icon(Icons.check_circle, color: Colors.amber, size: 22)),
        ])),
      ),
    );
  }

  Widget _buildCardWidget(UnoCard card, {bool big = false}) {
    final w = big ? 105.0 : 75.0; final h = big ? 155.0 : 110.0;
    final isWild = card.color == CardColor.wild; final isClear = card.type == CardType.clear;
    final bgColor = card.displayColor; final txtColor = (card.color == CardColor.yellow) ? Colors.black : Colors.white;
    return Container(width: w, height: h,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8, offset: const Offset(2, 4))]),
      child: Stack(children: [
        if (!isWild && !isClear) Center(child: Transform.rotate(angle: -0.3, child: Container(width: w * 0.7, height: h * 0.55, decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(40))))),
        Center(child: Text(card.displayText, style: TextStyle(fontSize: big ? 48 : 34, fontWeight: FontWeight.w900, color: txtColor, shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(1, 2))]))),
        if (card.type == CardType.number) Positioned(top: 6, left: 10, child: Text('${card.number}', style: TextStyle(fontSize: big ? 20 : 14, fontWeight: FontWeight.w900, color: txtColor))),
        if (isWild) Positioned(bottom: 0, left: 4, right: 4, child: Container(height: 5, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))))),
      ]),
    );
  }

  Color _getColorForCard(CardColor color) {
    switch (color) { case CardColor.red: return Colors.red; case CardColor.blue: return Colors.blue; case CardColor.green: return Colors.green; case CardColor.yellow: return Colors.amber; case CardColor.wild: return Colors.purple; }
  }
}
