#!/bin/bash

# ========== Обновлённый game_screen.dart ==========
cat > lib/screens/game_screen.dart << 'EOF'
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/game_state.dart';
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
  bool _isMyTurn = false;
  bool _gameStarted = false;
  String _direction = '➡️';
  
  // Множественный выбор карт
  final Set<String> _selectedCardIds = {};
  bool _multiSelectMode = false;

  @override
  void initState() {
    super.initState();
    _deck = UnoDeck(seed: 42);

    widget.server.onMessage = (GameMessage message) {
      _handleMessage(message);
    };

    if (widget.isHost) {
      _startGameAsHost();
    }
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

    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.startGame,
      data: _gameState.toJson(),
    ));
  }

  void _handleMessage(GameMessage message) {
    if (!mounted) return;

    switch (message.type) {
      case GameMessageType.startGame:
        setState(() {
          _gameState = UnoGameState.fromJson(message.data);
          _gameStarted = true;
          _updateTurn();
        });
        break;

      case GameMessageType.playCard:
      case GameMessageType.drawCard:
      case GameMessageType.gameState:
        setState(() {
          _gameState = UnoGameState.fromJson(message.data);
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

    if (_gameState.winner != null && mounted) {
      _showWinDialog(_gameState.winner!);
    }
  }

  // Проверка: можно ли сбросить несколько карт одного номинала
  List<UnoCard> _getMultiPlayableCards() {
    if (!_isMyTurn) return [];
    
    final hand = _gameState.currentHand(widget.playerName);
    final topCard = _gameState.topCard;
    
    // Группируем карты по номиналу (только number)
    Map<String, List<UnoCard>> groups = {};
    for (var card in hand) {
      if (card.type == CardType.number && card.canPlayOn(topCard)) {
        final key = '${card.number}';
        groups.putIfAbsent(key, () => []);
        groups[key]!.add(card);
      }
    }
    
    // Возвращаем группы где больше 1 карты
    for (var group in groups.values) {
      if (group.length >= 2) return group;
    }
    return [];
  }

  void _playCard(UnoCard card) {
    if (!_isMyTurn || !_gameStarted) return;
    if (!card.canPlayOn(_gameState.topCard)) return;

    // Проверяем множественный сброс
    final multiCards = _getMultiPlayableCards();
    if (multiCards.isNotEmpty && card.type == CardType.number) {
      // Начинаем множественный выбор
      setState(() {
        _multiSelectMode = true;
        _selectedCardIds.add(card.id);
      });
      return;
    }

    _executePlayCard([card]);
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

    // Удаляем карты из руки
    for (var card in cards) {
      _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
    }
    _gameState.discardPile.add(lastCard);

    // Проверка на ответ 2+ против 4+
    if (lastCard.type == CardType.wildDraw4) {
      _handleWildDraw4(lastCard);
    } else {
      _applyCardEffect(lastCard);
    }

    // Проверка победы
    if (_gameState.playerHands[widget.playerName]!.isEmpty) {
      _gameState.winner = widget.playerName;
    }

    if (lastCard.type != CardType.wildDraw4 || _gameState.pendingResponsePlayer == null) {
      _gameState.nextTurn();
    }
    _updateTurn();

    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.gameState,
      data: _gameState.toJson(),
    ));

    if (_gameState.winner != null) {
      _showWinDialog(_gameState.winner!);
    }
  }

  void _handleWildDraw4(UnoCard wildCard) {
    // Находим следующего игрока
    final nextIndex = _gameState.isClockwise
        ? (_gameState.currentPlayerIndex + 1) % _gameState.playerCount
        : (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount;
    final nextPlayer = _gameState.playerOrder[nextIndex];
    final nextHand = _gameState.playerHands[nextPlayer] ?? [];

    // Проверяем, есть ли у следующего игрока +2 выбранного цвета
    final hasDraw2 = nextHand.any((c) => 
      c.type == CardType.draw2 && c.color == _gameState.chosenColor);
    
    final hasOnlyDraw2 = hasDraw2 && nextHand.length == 1;

    if (hasOnlyDraw2) {
      // Если +2 единственная карта — игрок побеждает
      _gameState.winner = nextPlayer;
      _gameState.playerHands[nextPlayer]!.clear();
      return;
    }

    if (hasDraw2) {
      // Даём шанс ответить — текущий игрок берёт 6 карт
      _gameState.pendingResponsePlayer = nextPlayer;
      _gameState.pendingDrawCount = 6;
      return;
    }

    // Обычный +4 — следующий берёт 4
    _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(4));
  }

  void _respondToDraw4(UnoCard draw2Card) {
    // Игрок отвечает своей +2 на +4
    _gameState.playerHands[widget.playerName]!
        .removeWhere((c) => c.id == draw2Card.id);
    _gameState.discardPile.add(draw2Card);

    // Предыдущий игрок берёт 6 карт
    final prevIndex = _gameState.isClockwise
        ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount
        : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
    final prevPlayer = _gameState.playerOrder[prevIndex];
    _gameState.playerHands[prevPlayer]!.addAll(_deck.drawMultiple(6));

    _gameState.pendingResponsePlayer = null;
    _gameState.pendingDrawCount = 0;
    _gameState.nextTurn();
    _updateTurn();

    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.gameState,
      data: _gameState.toJson(),
    ));
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
        final nextPlayer = _gameState.currentPlayer;
        _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(2));
        break;
      default:
        break;
    }
  }

  void _drawCard() {
    if (!_isMyTurn || !_gameStarted) return;
    if (_gameState.pendingResponsePlayer == widget.playerName) {
      // Игрок не может ответить на +4, берёт 6 карт
      _gameState.playerHands[widget.playerName]!
          .addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 4));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
    } else {
      final card = _deck.draw();
      _gameState.playerHands[widget.playerName]!.add(card);
    }
    
    _gameState.drawPileCount = _deck.cards.length;
    _gameState.nextTurn();
    _updateTurn();

    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.gameState,
      data: _gameState.toJson(),
    ));
  }

  void _toggleCardSelection(UnoCard card) {
    if (!_multiSelectMode) return;
    setState(() {
      if (_selectedCardIds.contains(card.id)) {
        _selectedCardIds.remove(card.id);
      } else {
        _selectedCardIds.add(card.id);
      }
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

  @override
  Widget build(BuildContext context) {
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
    final multiCards = _multiSelectMode ? _getMultiPlayableCards() : [];

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
          // Игровое поле
          Expanded(
            flex: 2,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: (_isMyTurn || isPendingResponse) ? _drawCard : null,
                    child: Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.red, Colors.deepOrange]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('УНО', style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _buildCardWidget(_gameState.topCard, big: true),
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

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Colors.green.withOpacity(0.4)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: isCurrent
                        ? Border.all(color: Colors.greenAccent, width: 2)
                        : Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (player == widget.playerName)
                        const Icon(Icons.person, size: 14, color: Colors.yellow),
                      const SizedBox(width: 4),
                      Text(player, style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      const SizedBox(width: 4),
                      Text('$cardCount🃏', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          ),

          // Сообщения о режимах
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

          // Кнопка подтверждения для множественного сброса
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
                ? const Center(
                    child: Text('У вас нет карт!', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  )
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
                              margin: EdgeInsets.only(
                                top: (canTap || isPendingDraw2) ? 0 : 10,
                                bottom: isSelected ? 15 : 0,
                              ),
                              decoration: isSelected
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.8),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: Opacity(
                                opacity: (canTap || isPendingDraw2) ? 1.0 : 0.55,
                                child: Stack(
                                  children: [
                                    _buildCardWidget(card),
                                    if (isPendingDraw2)
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.reply, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    if (isSelected)
                                      const Positioned(
                                        top: -5,
                                        left: -5,
                                        child: Icon(Icons.check_circle, color: Colors.amber, size: 22),
                                      ),
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

  Widget _buildCardWidget(UnoCard card, {bool big = false}) {
    final w = big ? 100.0 : 70.0;
    final h = big ? 150.0 : 105.0;
    final isWild = card.color == CardColor.wild;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: card.displayColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.displayText,
              style: TextStyle(
                fontSize: big ? 40 : 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
                ],
              ),
            ),
            if (isWild)
              Container(
                width: w * 0.7,
                height: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
EOF

# ========== Обновлённый game_state.dart ==========
cat > lib/models/game_state.dart << 'EOF'
import 'card.dart';

class UnoGameState {
  final List<UnoCard> discardPile;
  final Map<String, List<UnoCard>> playerHands;
  final List<String> playerOrder;
  int currentPlayerIndex;
  bool isClockwise;
  String? winner;
  int drawPileCount;
  CardColor? chosenColor; // Цвет, выбранный при +4
  String? pendingResponsePlayer; // Кто должен ответить на +4
  int? pendingDrawCount; // Сколько карт брать если не ответит

  UnoGameState({
    required this.drawPileCount,
    required this.discardPile,
    required this.playerHands,
    required this.playerOrder,
    this.currentPlayerIndex = 0,
    this.isClockwise = true,
    this.winner,
    this.chosenColor,
    this.pendingResponsePlayer,
    this.pendingDrawCount,
  });

  UnoCard get topCard => discardPile.last;
  int get playerCount => playerOrder.length;
  String get currentPlayer => playerOrder[currentPlayerIndex];
  List<UnoCard> currentHand(String player) => playerHands[player] ?? [];

  void nextTurn() {
    if (isClockwise) {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
    } else {
      currentPlayerIndex = (currentPlayerIndex - 1 + playerCount) % playerCount;
    }
  }

  Map<String, dynamic> toJson() => {
    'discardPile': discardPile.map((c) => c.toJson()).toList(),
    'playerHands': playerHands.map(
      (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
    ),
    'playerOrder': playerOrder,
    'currentPlayerIndex': currentPlayerIndex,
    'isClockwise': isClockwise,
    'winner': winner,
    'drawPileCount': drawPileCount,
    'chosenColor': chosenColor?.name,
    'pendingResponsePlayer': pendingResponsePlayer,
    'pendingDrawCount': pendingDrawCount,
  };

  factory UnoGameState.fromJson(Map<String, dynamic> json) => UnoGameState(
    drawPileCount: json['drawPileCount'] ?? 0,
    discardPile: (json['discardPile'] as List)
        .map((c) => UnoCard.fromJson(c))
        .toList(),
    playerHands: (json['playerHands'] as Map).map(
      (k, v) => MapEntry(k, (v as List).map((c) => UnoCard.fromJson(c)).toList()),
    ),
    playerOrder: List<String>.from(json['playerOrder']),
    currentPlayerIndex: json['currentPlayerIndex'] ?? 0,
    isClockwise: json['isClockwise'] ?? true,
    winner: json['winner'],
    chosenColor: json['chosenColor'] != null 
        ? CardColor.values.byName(json['chosenColor']) 
        : null,
    pendingResponsePlayer: json['pendingResponsePlayer'],
    pendingDrawCount: json['pendingDrawCount'],
  );
}
EOF

echo "✅ Правила обновлены!"
echo "1) Сброс нескольких карт одного номинала за ход"
echo "2) Ответ 2+ на 4+ с взятием 6 карт"
echo "Запустите: git add -A && git commit -m 'Новые правила: множественный сброс и ответ на +4' && git push"
