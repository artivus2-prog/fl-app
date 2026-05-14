#!/bin/bash

# Создаём папки
mkdir -p lib/screens lib/models lib/services

# ========== models/card.dart (обновлённый) ==========
cat > lib/models/card.dart << 'EOF'
import 'dart:math';

enum CardColor { red, blue, green, yellow, wild }
enum CardType { number, skip, reverse, draw2, wild, wildDraw4 }

class UnoCard {
  final CardColor color;
  final CardType type;
  final int? number;
  final String id;

  UnoCard({
    required this.color,
    required this.type,
    this.number,
  }) : id = '${color.name}_${type.name}_${number ?? ""}_${Random().nextInt(10000)}';

  bool canPlayOn(UnoCard topCard) {
    if (color == CardColor.wild) return true;
    if (topCard.color == color) return true;
    if (topCard.type == type && type == CardType.number) {
      return topCard.number == number;
    }
    if (topCard.type == type && type != CardType.number) return true;
    return false;
  }

  Color get displayColor {
    switch (color) {
      case CardColor.red: return const Color(0xFFE53935);
      case CardColor.blue: return const Color(0xFF1E88E5);
      case CardColor.green: return const Color(0xFF43A047);
      case CardColor.yellow: return const Color(0xFFFDD835);
      case CardColor.wild: return const Color(0xFF212121);
    }
  }

  String get displayText {
    switch (type) {
      case CardType.number: return '$number';
      case CardType.skip: return '⊘';
      case CardType.reverse: return '⟲';
      case CardType.draw2: return '+2';
      case CardType.wild: return 'W';
      case CardType.wildDraw4: return '+4';
    }
  }

  Map<String, dynamic> toJson() => {
        'color': color.name,
        'type': type.name,
        'number': number,
        'id': id,
      };

  factory UnoCard.fromJson(Map<String, dynamic> json) => UnoCard(
        color: CardColor.values.byName(json['color']),
        type: CardType.values.byName(json['type']),
        number: json['number'],
      );
}

class UnoDeck {
  List<UnoCard> cards = [];

  UnoDeck() {
    _createDeck();
    shuffle();
  }

  void _createDeck() {
    for (var color in [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow]) {
      // Одна карта 0
      cards.add(UnoCard(color: color, type: CardType.number, number: 0));
      // Две карты 1-9
      for (int i = 1; i <= 9; i++) {
        cards.add(UnoCard(color: color, type: CardType.number, number: i));
        cards.add(UnoCard(color: color, type: CardType.number, number: i));
      }
      // Две карты действий
      for (int i = 0; i < 2; i++) {
        cards.add(UnoCard(color: color, type: CardType.skip));
        cards.add(UnoCard(color: color, type: CardType.reverse));
        cards.add(UnoCard(color: color, type: CardType.draw2));
      }
    }
    // Дикие карты
    for (int i = 0; i < 4; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wild));
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildDraw4));
    }
  }

  void shuffle() {
    cards.shuffle(Random());
  }

  UnoCard draw() {
    if (cards.isEmpty) {
      _createDeck();
      shuffle();
    }
    return cards.removeAt(0);
  }

  List<UnoCard> drawMultiple(int count) {
    List<UnoCard> drawn = [];
    for (int i = 0; i < count; i++) {
      drawn.add(draw());
    }
    return drawn;
  }
}
EOF

# ========== models/game_state.dart ==========
cat > lib/models/game_state.dart << 'EOF'
import 'card.dart';

class UnoGameState {
  List<UnoCard> drawPile;
  List<UnoCard> discardPile;
  Map<String, List<UnoCard>> playerHands;
  List<String> playerOrder;
  int currentPlayerIndex;
  bool isClockwise;
  String? winner;

  UnoGameState({
    required this.drawPile,
    required this.discardPile,
    required this.playerHands,
    required this.playerOrder,
    this.currentPlayerIndex = 0,
    this.isClockwise = true,
    this.winner,
  });

  UnoCard get topCard => discardPile.last;

  int get playerCount => playerOrder.length;

  String get currentPlayer => playerOrder[currentPlayerIndex];

  List<UnoCard> get currentHand => playerHands[currentPlayer] ?? [];

  void nextTurn() {
    if (isClockwise) {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
    } else {
      currentPlayerIndex = (currentPlayerIndex - 1 + playerCount) % playerCount;
    }
  }

  Map<String, dynamic> toJson() => {
        'drawPileCount': drawPile.length,
        'discardPile': discardPile.map((c) => c.toJson()).toList(),
        'playerHands': playerHands.map(
          (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
        ),
        'playerOrder': playerOrder,
        'currentPlayerIndex': currentPlayerIndex,
        'isClockwise': isClockwise,
        'winner': winner,
      };

  factory UnoGameState.fromJson(Map<String, dynamic> json) => UnoGameState(
        drawPile: [],
        discardPile: (json['discardPile'] as List)
            .map((c) => UnoCard.fromJson(c))
            .toList(),
        playerHands: (json['playerHands'] as Map).map(
          (k, v) => MapEntry(k, (v as List).map((c) => UnoCard.fromJson(c)).toList()),
        ),
        playerOrder: List<String>.from(json['playerOrder']),
        currentPlayerIndex: json['currentPlayerIndex'],
        isClockwise: json['isClockwise'],
        winner: json['winner'],
      );
}
EOF

# ========== screens/game_screen.dart ==========
cat > lib/screens/game_screen.dart << 'EOF'
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
EOF

# ========== Обновляем lobby_screen.dart (добавляем переход к игре) ==========
cat > lib/screens/lobby_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import '../services/game_server.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final bool isHost;
  final String? hostIp;

  const LobbyScreen({super.key, required this.isHost, this.hostIp});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final GameServer _server = GameServer();
  final List<String> _players = [];
  String? _myIp;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      _startHosting();
    }
  }

  Future<void> _startHosting() async {
    _myIp = await _server.getLocalIp();
    await _server.startHost(() {
      setState(() {
        _players.clear();
        _players.addAll(_server.players);
      });
    });
    setState(() {
      _connected = true;
      _players.insert(0, 'Вы (Хост)');
    });
  }

  Future<void> _connectToHost() async {
    if (widget.hostIp == null) return;
    try {
      await _server.connectToHost(widget.hostIp!);
      setState(() {
        _connected = true;
        _players.add('Вы');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось подключиться: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startGame() {
    // Формируем список имён для игры
    List<String> gamePlayers = [];
    if (widget.isHost) {
      gamePlayers.add('Хост');
      for (int i = 1; i < _players.length; i++) {
        gamePlayers.add('Игрок $i');
      }
    } else {
      gamePlayers = List.from(_players);
    }

    // Если меньше 2 игроков, добавляем ботов
    while (gamePlayers.length < 2) {
      gamePlayers.add('Бот ${gamePlayers.length}');
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          players: gamePlayers,
          isHost: widget.isHost,
          playerName: widget.isHost ? 'Хост' : 'Вы',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isHost ? 'Создание игры' : 'Подключение'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (widget.isHost && _myIp != null) ...[
              Card(
                color: Colors.blue.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Ваш IP адрес',
                              style: TextStyle(fontSize: 16, color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_myIp!,
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2)),
                      const SizedBox(height: 8),
                      const Text('Скажите друзьям этот адрес',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (!widget.isHost && !_connected) ...[
              Card(
                color: Colors.orange.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Подключение...',
                              style: TextStyle(fontSize: 16, color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text('Подключаемся к ${widget.hostIp}',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _connectToHost,
                        child: const Text('Подключиться'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Row(
              children: [
                const Icon(Icons.people, color: Colors.white),
                const SizedBox(width: 8),
                Text('Игроки (${_players.length}/5)',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _players.isEmpty
                  ? const Center(child: Text('Ожидание игроков...', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _players.length,
                      itemBuilder: (context, index) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.primaries[index % Colors.primaries.length],
                            child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(_players[index]),
                          trailing: index == 0
                              ? const Chip(label: Text('ХОСТ'), backgroundColor: Colors.green)
                              : null,
                        ),
                      ),
                    ),
            ),
            if (widget.isHost)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _players.length >= 2 ? _startGame : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: Text(_players.length >= 2 ? 'Начать игру' : 'Ожидайте игроков (минимум 2)'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (widget.isHost) _server.stopServer();
    super.dispose();
  }
}
EOF

echo "✅ Игровой стол готов!"
echo "Запустите: git add -A && git commit -m 'Добавил игровой стол с картами Уно' && git push"
