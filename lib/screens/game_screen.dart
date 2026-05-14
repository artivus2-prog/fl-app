import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/game_state.dart';

class GameScreen extends StatefulWidget {
  final List<String> players;
  final bool isHost;
  final String playerName;

  const GameScreen({
    super.key,
    required this.players,
    required this.isHost,
    required this.playerName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late UnoDeck _deck;
  late UnoGameState _gameState;
  bool _isMyTurn = false;
  UnoCard? _selectedCard;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _deck = UnoDeck();
    Map<String, List<UnoCard>> hands = {};

    for (var player in widget.players) {
      hands[player] = _deck.drawMultiple(7);
    }

    UnoCard firstCard;
    do {
      firstCard = _deck.draw();
    } while (firstCard.type != CardType.number);

    _gameState = UnoGameState(
      drawPile: _deck.cards,
      discardPile: [firstCard],
      playerHands: hands,
      playerOrder: widget.players,
      currentPlayerIndex: 0,
    );

    setState(() {
      _isMyTurn = _gameState.currentPlayer == widget.playerName;
    });
  }

  void _playCard(UnoCard card) {
    if (!_isMyTurn) return;
    if (!card.canPlayOn(_gameState.topCard)) return;

    setState(() {
      _gameState.playerHands[widget.playerName]!.remove(card);
      _gameState.discardPile.add(card);

      // Специальные эффекты
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

      _gameState.nextTurn();
      _isMyTurn = _gameState.currentPlayer == widget.playerName;
      _selectedCard = null;

      // Проверка победы
      if (_gameState.playerHands[widget.playerName]!.isEmpty) {
        _gameState.winner = widget.playerName;
        _showWinDialog();
      }
    });
  }

  void _drawCard() {
    if (!_isMyTurn) return;

    setState(() {
      final card = _deck.draw();
      _gameState.playerHands[widget.playerName]!.add(card);
      _gameState.nextTurn();
      _isMyTurn = _gameState.currentPlayer == widget.playerName;
    });
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Победа!'),
        content: Text('${_gameState.winner} выиграл!'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // На главный экран
            },
            child: const Text('В меню'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myHand = _gameState.playerHands[widget.playerName] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уно'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isMyTurn)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Chip(
                label: Text('ВАШ ХОД'),
                backgroundColor: Colors.green,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Верхняя карта и колода
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
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Text('УНО',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Верхняя карта
                  _buildCard(_gameState.topCard, big: true),
                ],
              ),
            ),
          ),

          // Информация о других игроках
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.players.length,
              itemBuilder: (context, index) {
                final player = widget.players[index];
                final isCurrent = player == _gameState.currentPlayer;
                final cardCount = _gameState.playerHands[player]?.length ?? 0;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Colors.green.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrent
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        player,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Text(
                        '$cardCount 🃏',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Мои карты
          Expanded(
            flex: 3,
            child: myHand.isEmpty
                ? const Center(child: Text('Нет карт'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: myHand.map((card) {
                        final canPlay = _isMyTurn && card.canPlayOn(_gameState.topCard);
                        return GestureDetector(
                          onTap: canPlay ? () => _playCard(card) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Opacity(
                              opacity: canPlay ? 1.0 : 0.5,
                              child: _buildCard(card),
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

  Widget _buildCard(UnoCard card, {bool big = false}) {
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
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
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
                fontSize: big ? 36 : 28,
                fontWeight: FontWeight.w900,
                color: isWild ? Colors.white : Colors.white,
              ),
            ),
            if (isWild)
              Container(
                width: w * 0.8,
                height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
