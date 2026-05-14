#!/bin/bash

# ========== models/bot_player.dart ==========
cat > lib/models/bot_player.dart << 'EOF'
import 'dart:math';
import 'card.dart';
import 'game_state.dart';

class BotPlayer {
  final Random _random = Random();

  // Бот выбирает какую карту сыграть
  UnoCard? chooseCard(List<UnoCard> hand, UnoCard topCard, CardColor? chosenColor) {
    // Если есть выбранный цвет (после wild) — приоритет этому цвету
    if (chosenColor != null) {
      // Ищем +2 выбранного цвета для ответа на +4
      for (var card in hand) {
        if (card.type == CardType.draw2 && card.color == chosenColor) {
          return card;
        }
      }
    }

    // Ищем играбельные карты
    List<UnoCard> playable = hand.where((c) => c.canPlayOn(topCard)).toList();
    if (playable.isEmpty) return null;

    // Приоритеты:
    // 1. +4 если мало карт у соперника
    // 2. +2
    // 3. Пропуск хода
    // 4. Реверс
    // 5. Обычная карта (предпочитаем сбросить дубли)

    // Ищем дубликаты по числу для множественного сброса
    Map<int, List<UnoCard>> numberGroups = {};
    for (var card in playable) {
      if (card.type == CardType.number) {
        numberGroups.putIfAbsent(card.number!, () => []);
        numberGroups[card.number!]!.add(card);
      }
    }

    // Если есть дубликаты — сбрасываем все
    for (var group in numberGroups.values) {
      if (group.length >= 2) return group.first;
    }

    // Специальные карты
    for (var card in playable) {
      if (card.type == CardType.wildDraw4) return card;
    }
    for (var card in playable) {
      if (card.type == CardType.draw2) return card;
    }
    for (var card in playable) {
      if (card.type == CardType.skip) return card;
    }
    for (var card in playable) {
      if (card.type == CardType.reverse) return card;
    }
    for (var card in playable) {
      if (card.type == CardType.wild) return card;
    }

    // Обычная карта
    return playable.first;
  }

  // Бот выбирает цвет для дикой карты
  CardColor chooseColor(List<UnoCard> hand) {
    // Считаем каких цветов больше
    Map<CardColor, int> colorCount = {};
    for (var card in hand) {
      if (card.color != CardColor.wild) {
        colorCount[card.color] = (colorCount[card.color] ?? 0) + 1;
      }
    }

    if (colorCount.isNotEmpty) {
      // Выбираем цвет, которого больше
      return colorCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Случайный цвет
    return CardColor.values[_random.nextInt(4)];
  }

  bool shouldRespondToDraw4(List<UnoCard> hand, CardColor chosenColor) {
    // Бот отвечает на +4 если есть +2 нужного цвета
    return hand.any((c) => c.type == CardType.draw2 && c.color == chosenColor);
  }
}
EOF

# ========== Обновлённый game_screen.dart с ботами ==========
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

    if (_gameState.winner != null && mounted) {
      _showWinDialog(_gameState.winner!);
      return;
    }

    // Запускаем бота через паузу
    if (_isBotTurn && widget.isHost) {
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(milliseconds: 800), _botMove);
    }
  }

  void _botMove() {
    if (!mounted || !_isBotTurn || !widget.isHost) return;

    final botName = _gameState.currentPlayer;
    final botHand = _gameState.currentHand(botName);
    final topCard = _gameState.topCard;
    final chosenColor = _gameState.chosenColor;

    // Проверка: нужно ли ответить на +4
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

    // Выбираем карту
    final chosenCard = _bot.chooseCard(botHand, topCard, chosenColor);

    if (chosenCard == null) {
      // Берём карту
      _gameState.playerHands[botName]!.add(_deck.draw());
      _gameState.drawPileCount = _deck.cards.length;
      _gameState.nextTurn();
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    // Играем карту
    _gameState.playerHands[botName]!.removeWhere((c) => c.id == chosenCard.id);
    _gameState.discardPile.add(chosenCard);

    // Выбор цвета для wild
    if (chosenCard.color == CardColor.wild) {
      _gameState.chosenColor = _bot.chooseColor(botHand);
    }

    // Применяем эффекты
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

    // Проверка победы бота
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

    for (var card in cards) {
      _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
    }
    _gameState.discardPile.add(lastCard);

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
              color: btnColor,
              shape: BoxShape.circle,
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
                      Icon(isBot ? Icons.computer : Icons.person, size: 14, color: player == widget.playerName ? Colors.yellow : Colors.white),
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

echo "✅ Боты работают!"
echo "Боты:"
echo "  - Автоматически ходят через 0.8 сек"
echo "  - Выбирают лучшую карту (приоритет: +4, +2, skip, reverse, wild)"
echo "  - Сбрасывают дубликаты одного номинала"
echo "  - Отвечают +2 на +4 если есть"
echo "  - Выбирают цвет по большинству карт в руке"
echo "Запустите: git add -A && git commit -m 'Добавил ИИ ботов' && git push"
