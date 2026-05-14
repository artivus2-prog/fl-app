#!/bin/bash

# ========== Обновлённый game_screen.dart с кнопкой УНО и таймером ==========
cat > lib/screens/game_screen.dart << 'EOF'
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

class _GameScreenState extends State<GameScreen> {
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
  Timer? _unoTimer;
  
  // УНО
  bool _unoPressed = false;
  int _unoSecondsLeft = 10;
  bool _unoWarning = false; // Осталась 1 карта — нужно нажать УНО

  bool get _isBotTurn => _gameState.currentPlayer.startsWith('Бот');

  @override
  void initState() {
    super.initState();
    _deck = UnoDeck(seed: 42);
    widget.server.onMessage = (GameMessage message) => _handleMessage(message);
    if (widget.isHost) _startGameAsHost();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _unoTimer?.cancel();
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
    switch (message.type) {
      case GameMessageType.startGame:
      case GameMessageType.playCard:
      case GameMessageType.drawCard:
      case GameMessageType.gameState:
        setState(() {
          _gameState = UnoGameState.fromJson(message.data);
          _gameStarted = true;
          _updateTurn();
        });
        break;
      default:
        break;
    }
  }

  void _updateTurn() {
    _isMyTurn = _gameState.currentPlayer == widget.playerName;
    _direction = _gameState.isClockwise ? '➡️' : '⬅️';
    _selectedCardIds.clear();
    _multiSelectMode = false;
    _choosingColor = false;
    _pendingWildCard = null;
    _unoTimer?.cancel();
    _unoSecondsLeft = 10;

    if (_gameState.winner != null && mounted) {
      _showWinDialog(_gameState.winner!);
      return;
    }

    // Проверка: у текущего игрока 2 карты? Нужно нажать УНО после сброса
    final currentHand = _gameState.currentHand(_gameState.currentPlayer);
    if (currentHand.length == 2 && _gameState.currentPlayer == widget.playerName) {
      _unoPressed = false; // Сбрасываем перед ходом
    }

    if (_isBotTurn && widget.isHost) {
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(milliseconds: 800), _botMove);
    }
  }

  // Штраф за не нажатое УНО
  void _applyUnoPenalty(String player) {
    if (_gameState.playerHands[player]!.length == 1 && !_unoPressed) {
      // Игрок сбросил карту и у него осталась 1, но УНО не нажато — штраф 2 карты
      setState(() {
        _gameState.playerHands[player]!.addAll(_deck.drawMultiple(2));
        _gameState.drawPileCount = _deck.cards.length;
      });
      _showUnoPenaltyMessage(player);
    }
  }

  void _showUnoPenaltyMessage(String player) {
    if (!mounted) return;
    final isMe = player == widget.playerName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isMe
            ? '⚠️ Вы не нажали УНО! Штраф +2 карты!'
            : '⚠️ $player не нажал УНО! Штраф +2 карты!'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _pressUno() {
    setState(() {
      _unoPressed = true;
      _unoSecondsLeft = 10;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ УНО!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
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
          // Штраф если не нажато УНО, а карта уже сброшена
          if (!_unoPressed && _gameState.currentHand(widget.playerName).length == 1) {
            _applyUnoPenalty(widget.playerName);
          }
        }
      });
    });
  }

  void _botMove() {
    if (!mounted || !_isBotTurn || !widget.isHost) return;

    final botName = _gameState.currentPlayer;
    final botHand = _gameState.currentHand(botName);
    final topCard = _gameState.topCard;
    final chosenColor = _gameState.chosenColor;

    // Бот всегда нажимает УНО если у него 2 карты перед сбросом
    final botUnoPressed = botHand.length == 2;

    if (_gameState.pendingResponsePlayer == botName) {
      if (_bot.shouldRespondToDraw4(botHand, chosenColor!)) {
        final draw2 = botHand.firstWhere(
            (c) => c.type == CardType.draw2 && c.color == chosenColor);
        _gameState.playerHands[botName]!.removeWhere((c) => c.id == draw2.id);
        _gameState.discardPile.add(draw2);
        final prevIndex = _gameState.isClockwise
            ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount
            : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
        _gameState.playerHands[_gameState.playerOrder[prevIndex]]!
            .addAll(_deck.drawMultiple(6));
        _gameState.pendingResponsePlayer = null;
        _gameState.pendingDrawCount = 0;
      } else {
        _gameState.playerHands[botName]!
            .addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 4));
        _gameState.pendingResponsePlayer = null;
        _gameState.pendingDrawCount = 0;
      }
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

    // Бот нажимает УНО
    if (botUnoPressed && _gameState.playerHands[botName]!.length == 1) {
      // Успешно нажал
    } else if (botHand.length == 2 && !botUnoPressed) {
      // Не нажал — штраф
      _gameState.playerHands[botName]!.addAll(_deck.drawMultiple(2));
    }

    if (chosenCard.color == CardColor.wild) {
      _gameState.chosenColor = _bot.chooseColor(botHand);
    }

    if (chosenCard.type == CardType.wildDraw4) {
      final nextIndex = _gameState.isClockwise
          ? (_gameState.currentPlayerIndex + 1) % _gameState.playerCount
          : (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount;
      final nextPlayer = _gameState.playerOrder[nextIndex];
      final nextHand = _gameState.playerHands[nextPlayer] ?? [];
      final hasDraw2 = nextHand.any(
          (c) => c.type == CardType.draw2 && c.color == _gameState.chosenColor);
      final hasOnlyDraw2 = hasDraw2 && nextHand.length == 1;

      if (hasOnlyDraw2) {
        _gameState.winner = nextPlayer;
        _gameState.playerHands[nextPlayer]!.clear();
      } else if (hasDraw2) {
        _gameState.pendingResponsePlayer = nextPlayer;
        _gameState.pendingDrawCount = 6;
      } else {
        _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(4));
      }
    } else {
      _applyCardEffect(chosenCard);
    }

    if (_gameState.playerHands[botName]!.isEmpty) {
      _gameState.winner = botName;
    }

    if (chosenCard.type != CardType.wildDraw4 || _gameState.pendingResponsePlayer == null) {
      _gameState.nextTurn();
    }

    setState(() => _updateTurn());
    _broadcastState();

    if (_gameState.winner != null) {
      _showWinDialog(_gameState.winner!);
    }
  }

  void _playCard(UnoCard card) {
    if (!_isMyTurn || !_gameStarted) return;
    if (!card.canPlayOn(_gameState.topCard)) return;

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
        _selectedCardIds.add(card.id);
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
    final cards = _gameState.currentHand(widget.playerName)
        .where((c) => _selectedCardIds.contains(c.id))
        .toList();
    _executePlayCard(cards);
  }

  void _executePlayCard(List<UnoCard> cards) {
    if (cards.isEmpty) return;
    final lastCard = cards.last;
    final handBefore = _gameState.currentHand(widget.playerName).length;

    for (var card in cards) {
      _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
    }
    _gameState.discardPile.add(lastCard);

    // Проверка УНО: было 2 карты, сбросили N, осталась 1 — надо было нажать
    if (handBefore == 2 && _gameState.currentHand(widget.playerName).length == 1) {
      if (!_unoPressed) {
        _applyUnoPenalty(widget.playerName);
      }
    }

    if (lastCard.type == CardType.wildDraw4) {
      _handleWildDraw4(lastCard);
    } else {
      _applyCardEffect(lastCard);
    }

    if (_gameState.playerHands[widget.playerName]!.isEmpty) {
      _gameState.winner = widget.playerName;
    }

    if (lastCard.type != CardType.wildDraw4 || _gameState.pendingResponsePlayer == null) {
      _gameState.nextTurn();
    }
    _updateTurn();
    _broadcastState();

    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
  }

  void _handleWildDraw4(UnoCard wildCard) {
    final nextIndex = _gameState.isClockwise
        ? (_gameState.currentPlayerIndex + 1) % _gameState.playerCount
        : (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount;
    final nextPlayer = _gameState.playerOrder[nextIndex];
    final nextHand = _gameState.playerHands[nextPlayer] ?? [];
    final chosenColor = _gameState.chosenColor;
    if (chosenColor == null) return;

    final hasDraw2 = nextHand.any((c) => c.type == CardType.draw2 && c.color == chosenColor);
    final hasOnlyDraw2 = hasDraw2 && nextHand.length == 1;

    if (hasOnlyDraw2) {
      _gameState.winner = nextPlayer;
      _gameState.playerHands[nextPlayer]!.clear();
      return;
    }
    if (hasDraw2) {
      _gameState.pendingResponsePlayer = nextPlayer;
      _gameState.pendingDrawCount = 6;
      return;
    }
    _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(4));
  }

  void _respondToDraw4(UnoCard draw2Card) {
    _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == draw2Card.id);
    _gameState.discardPile.add(draw2Card);
    final prevIndex = _gameState.isClockwise
        ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount
        : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
    _gameState.playerHands[_gameState.playerOrder[prevIndex]]!.addAll(_deck.drawMultiple(6));
    _gameState.pendingResponsePlayer = null;
    _gameState.pendingDrawCount = 0;
    _gameState.nextTurn();
    _updateTurn();
    _broadcastState();
  }

  void _applyCardEffect(UnoCard card) {
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
        _gameState.playerHands[_gameState.currentPlayer]!.addAll(_deck.drawMultiple(2));
        break;
      default:
        break;
    }
  }

  void _drawCard() {
    if (!_isMyTurn && _gameState.pendingResponsePlayer != widget.playerName) return;
    if (!_gameStarted) return;

    if (_gameState.pendingResponsePlayer == widget.playerName) {
      _gameState.playerHands[widget.playerName]!
          .addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 4));
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
      if (card.type == CardType.number && card.canPlayOn(topCard)) {
        final key = '${card.number}';
        groups.putIfAbsent(key, () => []);
        groups[key]!.add(card);
      }
    }
    for (var group in groups.values) {
      if (group.length >= 2) return group;
    }
    return [];
  }

  void _toggleCardSelection(UnoCard card) {
    if (!_multiSelectMode) return;
    setState(() {
      _selectedCardIds.contains(card.id)
          ? _selectedCardIds.remove(card.id)
          : _selectedCardIds.add(card.id);
    });
  }

  void _showWinDialog(String winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Text(winner == widget.playerName ? 'Вы победили!' : 'Победа!'),
          ],
        ),
        content: Text(
          winner == widget.playerName
              ? 'Отличная игра! Вы выиграли!'
              : '$winner выиграл игру!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.server.stop();
              Navigator.pop(context);
            },
            child: const Text('В меню'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.isHost) {
                setState(() {
                  _deck = UnoDeck(seed: Random().nextInt(99999));
                  _startGameAsHost();
                });
              }
            },
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
        title: const Row(
          children: [
            Icon(Icons.palette, color: Colors.purple),
            SizedBox(width: 12),
            Text('Выберите цвет'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Дикая карта — выберите следующий цвет:',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _colorButton(CardColor.red, 'Красный', ctx),
                _colorButton(CardColor.blue, 'Синий', ctx),
                _colorButton(CardColor.green, 'Зелёный', ctx),
                _colorButton(CardColor.yellow, 'Жёлтый', ctx),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorButton(CardColor color, String label, BuildContext ctx) {
    Color btnColor;
    switch (color) {
      case CardColor.red: btnColor = Colors.red; break;
      case CardColor.blue: btnColor = Colors.blue; break;
      case CardColor.green: btnColor = Colors.green; break;
      case CardColor.yellow: btnColor = Colors.amber; break;
      default: btnColor = Colors.grey;
    }
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _onColorChosen(color);
      },
      child: Column(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: btnColor, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: btnColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_choosingColor) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showColorPicker());
    }
    if (!_gameStarted) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Ожидание начала игры...', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    final myHand = _gameState.currentHand(widget.playerName);
    final isPendingResponse = _gameState.pendingResponsePlayer == widget.playerName;
    final botThinking = _isBotTurn;
    final showUnoButton = myHand.length == 2 && _isMyTurn && !_unoPressed;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Уно '),
            Text(_direction, style: const TextStyle(fontSize: 20)),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app),
          onPressed: () {
            widget.server.stop();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (botThinking)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('БОТ ДУМАЕТ...', style: TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: Colors.purple,
                avatar: SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
          if (isPendingResponse)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('ОТВЕТЬТЕ!', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.orange,
              ),
            ),
          if (_isMyTurn && !isPendingResponse)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('ВАШ ХОД', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.green,
                avatar: Icon(Icons.play_arrow, size: 16),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Кнопка УНО и таймер
          if (showUnoButton || (_unoPressed && myHand.length == 1))
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _unoPressed
                      ? [Colors.green, Colors.greenAccent]
                      : [Colors.red, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 12)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_unoPressed && myHand.length == 2) ...[
                    const Icon(Icons.warning, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('НАЖМИТЕ УНО!',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                          Text('$_unoSecondsLeft сек до штрафа',
                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _pressUno,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: const Text('УНО!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      ),
                    ),
                  ] else if (_unoPressed) ...[
                    const Icon(Icons.check_circle, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    const Text('УНО принято!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ],
              ),
            ),

          // Игровое поле
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: (_isMyTurn || isPendingResponse) ? _drawCard : null,
                        child: Container(
                          width: 80, height: 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.red, Colors.deepOrange]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(3, 3))],
                          ),
                          child: const Center(
                            child: Text('УНО', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      _buildCardWidget(_gameState.topCard, big: true),
                    ],
                  ),
                  if (_gameState.chosenColor != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getColorForCard(_gameState.chosenColor!).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Цвет: ${_gameState.chosenColor!.name.toUpperCase()}',
                        style: TextStyle(color: _getColorForCard(_gameState.chosenColor!), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Полоска с игроками
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.players.length,
              itemBuilder: (context, index) {
                final player = widget.players[index];
                final isCurrent = player == _gameState.currentPlayer;
                final cardCount = _gameState.playerHands[player]?.length ?? 0;
                final isBot = player.startsWith('Бот');
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent ? Colors.green.withOpacity(0.4) : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: isCurrent ? Border.all(color: Colors.greenAccent, width: 2) : Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isBot ? Icons.computer : Icons.person,
                          size: 14,
                          color: player == widget.playerName ? Colors.yellow : Colors.white),
                      const SizedBox(width: 4),
                      Text(player, style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      const SizedBox(width: 4),
                      Text('$cardCount🃏', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          ),

          if (_multiSelectMode)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.amber.withOpacity(0.3),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 18),
                  SizedBox(width: 8),
                  Text('Выберите одинаковые карты для сброса', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          if (isPendingResponse)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.3),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, size: 18),
                  SizedBox(width: 8),
                  Text('Ответьте своей +2 или возьмите 6 карт!', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          if (_multiSelectMode && _selectedCardIds.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirmMultiPlay,
                  style: FilledButton.styleFrom(backgroundColor: Colors.amber),
                  child: const Text('Сбросить выбранные карты'),
                ),
              ),
            ),

          // Карты игрока
          Expanded(
            flex: 3,
            child: myHand.isEmpty
                ? const Center(child: Text('У вас нет карт!', style: TextStyle(fontSize: 18, color: Colors.grey)))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: myHand.map((card) {
                        final canPlay = _isMyTurn && card.canPlayOn(_gameState.topCard);
                        final isPendingDraw2 = isPendingResponse &&
                            card.type == CardType.draw2 &&
                            card.color == _gameState.chosenColor;
                        final isSelected = _selectedCardIds.contains(card.id);
                        final canTap = canPlay || isPendingDraw2;

                        return GestureDetector(
                          onTap: () {
                            if (isPendingDraw2) {
                              _respondToDraw4(card);
                            } else if (_multiSelectMode && card.type == CardType.number && canPlay) {
                              _toggleCardSelection(card);
                            } else if (canTap) {
                              _playCard(card);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(top: (canTap || isPendingDraw2) ? 0 : 10, bottom: isSelected ? 15 : 0),
                              decoration: isSelected
                                  ? BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.8), blurRadius: 12, spreadRadius: 2)])
                                  : null,
                              child: Opacity(
                                opacity: (canTap || isPendingDraw2) ? 1.0 : 0.55,
                                child: Stack(
                                  children: [
                                    _buildCardWidget(card),
                                    if (isPendingDraw2)
                                      Positioned(
                                        top: -5, right: -5,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                          child: const Icon(Icons.reply, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    if (isSelected)
                                      const Positioned(top: -5, left: -5, child: Icon(Icons.check_circle, color: Colors.amber, size: 22)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
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

  Widget _buildCardWidget(UnoCard card, {bool big = false}) {
    final w = big ? 100.0 : 70.0;
    final h = big ? 150.0 : 105.0;
    final isWild = card.color == CardColor.wild;
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: card.displayColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, offset: const Offset(2, 3))],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(card.displayText, style: TextStyle(fontSize: big ? 40 : 30, fontWeight: FontWeight.w900, color: Colors.white, shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))])),
            if (isWild) Container(width: w * 0.7, height: 5, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue]), borderRadius: BorderRadius.all(Radius.circular(3)))),
          ],
        ),
      ),
    );
  }
}
EOF

echo "✅ Кнопка УНО и таймер 10 секунд добавлены!"
echo "Правила:"
echo "  - Когда у игрока 2 карты и его ход — появляется красная кнопка УНО"
echo "  - Таймер 10 секунд"
echo "  - Если не нажать до сброса карты — штраф +2 карты"
echo "  - Боты всегда нажимают УНО вовремя"
echo "Запустите: git add -A && git commit -m 'Кнопка УНО с таймером 10 сек' && git push"
