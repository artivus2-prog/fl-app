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

    // Отправляем состояние всем
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
        setState(() {
          _gameState = UnoGameState.fromJson(message.data);
          _updateTurn();
        });
        break;

      case GameMessageType.drawCard:
        setState(() {
          _gameState = UnoGameState.fromJson(message.data);
          _updateTurn();
        });
        break;

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

    if (_gameState.winner != null && mounted) {
      _showWinDialog(_gameState.winner!);
    }
  }

  void _playCard(UnoCard card) {
    if (!_isMyTurn || !_gameStarted) return;
    if (!card.canPlayOn(_gameState.topCard)) return;

    // Удаляем карту из руки
    _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
    _gameState.discardPile.add(card);

    // Применяем эффекты
    _applyCardEffect(card);

    // Проверка победы
    if (_gameState.playerHands[widget.playerName]!.isEmpty) {
      _gameState.winner = widget.playerName;
    }

    _gameState.nextTurn();
    _updateTurn();

    // Отправляем новое состояние
    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.gameState,
      data: _gameState.toJson(),
    ));

    if (_gameState.winner != null) {
      _showWinDialog(_gameState.winner!);
    }
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
      case CardType.wildDraw4:
        _gameState.nextTurn();
        final nextPlayer = _gameState.currentPlayer;
        _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(4));
        break;
      default:
        break;
    }
  }

  void _drawCard() {
    if (!_isMyTurn || !_gameStarted) return;

    final card = _deck.draw();
    _gameState.playerHands[widget.playerName]!.add(card);
    _gameState.drawPileCount = _deck.cards.length;
    _gameState.nextTurn();
    _updateTurn();

    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.gameState,
      data: _gameState.toJson(),
    ));
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
              Text('Ожидание начала игры...'),
            ],
          ),
        ),
      );
    }

    final myHand = _gameState.currentHand(widget.playerName);

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
          if (_isMyTurn)
            const Padding(
              padding: EdgeInsets.only(right: 12),
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
          // Игровое поле: колода + верхняя карта
          Expanded(
            flex: 2,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Колода
                  GestureDetector(
                    onTap: _isMyTurn ? _drawCard : null,
                    child: Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.deepOrange],
                        ),
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
                        child: Text('УНО',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Верхняя карта
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
                      Text(
                        player,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('$cardCount🃏', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

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
                        return GestureDetector(
                          onTap: canPlay ? () => _playCard(card) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(top: canPlay ? 0 : 10),
                              child: Opacity(
                                opacity: canPlay ? 1.0 : 0.55,
                                child: _buildCardWidget(card),
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
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
