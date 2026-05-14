#!/bin/bash

mkdir -p lib/screens lib/models lib/services

# ========== services/game_server.dart (обновлённый) ==========
cat > lib/services/game_server.dart << 'EOF'
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum GameMessageType {
  join, playerList, startGame, playCard, drawCard,
  gameState, chat, playerWon, nextTurn
}

class GameMessage {
  final GameMessageType type;
  final Map<String, dynamic> data;
  final String? fromPlayer;

  GameMessage({required this.type, required this.data, this.fromPlayer});

  String toJson() => jsonEncode({
    'type': type.name,
    'data': data,
    'fromPlayer': fromPlayer,
  });

  factory GameMessage.fromJson(String json) {
    final map = jsonDecode(json);
    return GameMessage(
      type: GameMessageType.values.byName(map['type']),
      data: map['data'],
      fromPlayer: map['fromPlayer'],
    );
  }
}

class GameServer {
  HttpServer? _server;
  WebSocket? _clientSocket;
  final List<WebSocket> _clients = [];
  final List<String> _players = [];
  final int port;
  Function(GameMessage)? onMessage;
  String _playerName = '';

  GameServer({this.port = 8080});

  bool get isHosting => _server != null;
  bool get isConnected => _clientSocket != null;
  List<String> get players => List.unmodifiable(_players);
  String get playerName => _playerName;

  Future<String> getLocalIp() async {
    final interfaces = await NetworkInterface.list();
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  // Запуск сервера (хост)
  Future<void> startHost(String playerName, VoidCallback onPlayerJoined) async {
    _playerName = playerName;
    _players.add(playerName);
    
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    debugPrint('Сервер запущен на порту $port');

    _server!.listen((HttpRequest request) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocketTransformer.upgrade(request).then((WebSocket socket) {
          _clients.add(socket);
          final newPlayer = 'Игрок ${_players.length}';
          _players.add(newPlayer);

          // Отправляем новому игроку его имя
          socket.add(GameMessage(
            type: GameMessageType.join,
            data: {'playerName': newPlayer, 'players': _players},
          ).toJson());

          // Всем остальным — обновлённый список
          _broadcast(GameMessage(
            type: GameMessageType.playerList,
            data: {'players': _players},
          ), exclude: socket);

          onPlayerJoined();

          socket.listen((data) {
            final message = GameMessage.fromJson(data);
            if (onMessage != null) onMessage!(message);
            // Пересылаем всем кроме отправителя
            _broadcast(message, exclude: socket);
          }, onDone: () {
            final idx = _clients.indexOf(socket);
            if (idx >= 0) {
              _clients.removeAt(idx);
              _players.removeAt(idx + 1);
            }
            _broadcast(GameMessage(
              type: GameMessageType.playerList,
              data: {'players': _players},
            ));
          });
        });
      }
    });
  }

  // Подключение к серверу (клиент)
  Future<void> connectToHost(String ip, String playerName) async {
    _playerName = playerName;
    _clientSocket = await WebSocket.connect('ws://$ip:$port');
    
    // Отправляем запрос на присоединение
    _clientSocket!.add(GameMessage(
      type: GameMessageType.join,
      data: {'playerName': playerName},
    ).toJson());

    _clientSocket!.listen((data) {
      final message = GameMessage.fromJson(data);
      if (message.type == GameMessageType.join) {
        _players.clear();
        _players.addAll(List<String>.from(message.data['players']));
        _playerName = message.data['playerName'];
      } else if (message.type == GameMessageType.playerList) {
        _players.clear();
        _players.addAll(List<String>.from(message.data['players']));
      }
      if (onMessage != null) onMessage!(message);
    });
  }

  void _broadcast(GameMessage message, {WebSocket? exclude}) {
    final json = message.toJson();
    for (var client in _clients) {
      if (client != exclude) {
        client.add(json);
      }
    }
  }

  void sendToHost(GameMessage message) {
    if (_clientSocket != null) {
      _clientSocket!.add(message.toJson());
    } else if (_server != null) {
      if (onMessage != null) onMessage!(message);
      _broadcast(message);
    }
  }

  void broadcastAll(GameMessage message) {
    if (_server != null) {
      _broadcast(message);
      if (onMessage != null) onMessage!(message);
    } else if (_clientSocket != null) {
      _clientSocket!.add(message.toJson());
    }
  }

  void stop() {
    for (var client in _clients) {
      client.close();
    }
    _clientSocket?.close();
    _server?.close();
    _server = null;
    _clientSocket = null;
    _clients.clear();
    _players.clear();
  }
}
EOF

# ========== models/card.dart (без изменений, но перезапишем для уверенности) ==========
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
      case CardColor.wild: return const Color(0xFF424242);
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
  final Random _random;

  UnoDeck({int? seed}) : _random = Random(seed) {
    _createDeck();
    shuffle();
  }

  void _createDeck() {
    cards.clear();
    for (var color in [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow]) {
      cards.add(UnoCard(color: color, type: CardType.number, number: 0));
      for (int i = 1; i <= 9; i++) {
        cards.add(UnoCard(color: color, type: CardType.number, number: i));
        cards.add(UnoCard(color: color, type: CardType.number, number: i));
      }
      for (int i = 0; i < 2; i++) {
        cards.add(UnoCard(color: color, type: CardType.skip));
        cards.add(UnoCard(color: color, type: CardType.reverse));
        cards.add(UnoCard(color: color, type: CardType.draw2));
      }
    }
    for (int i = 0; i < 4; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wild));
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildDraw4));
    }
  }

  void shuffle() {
    cards.shuffle(_random);
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
  final List<UnoCard> discardPile;
  final Map<String, List<UnoCard>> playerHands;
  final List<String> playerOrder;
  int currentPlayerIndex;
  bool isClockwise;
  String? winner;
  int drawPileCount;

  UnoGameState({
    required this.drawPileCount,
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
  );
}
EOF

# ========== screens/game_screen.dart (сетевой) ==========
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
EOF

# ========== Обновляем lobby_screen.dart ==========
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
  String _playerName = '';

  @override
  void initState() {
    super.initState();
    _playerName = widget.isHost ? 'Хост' : 'Гость';
    
    if (widget.isHost) {
      _startHosting();
    } else {
      _connectToHost();
    }
  }

  Future<void> _startHosting() async {
    _myIp = await _server.getLocalIp();
    await _server.startHost(_playerName, () {
      if (mounted) {
        setState(() {
          _players.clear();
          _players.addAll(_server.players);
        });
      }
    });
    setState(() {
      _connected = true;
      _players.clear();
      _players.addAll(_server.players);
    });
  }

  Future<void> _connectToHost() async {
    if (widget.hostIp == null) return;
    try {
      await _server.connectToHost(widget.hostIp!, _playerName);
      setState(() {
        _connected = true;
        _players.clear();
        _players.addAll(_server.players);
      });

      _server.onMessage = (GameMessage message) {
        if (mounted) {
          setState(() {
            _players.clear();
            _players.addAll(_server.players);
          });

          if (message.type == GameMessageType.startGame) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => GameScreen(
                  server: _server,
                  players: List.from(_server.players),
                  isHost: false,
                  playerName: _server.playerName,
                ),
              ),
            );
          }
        }
      };
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          server: _server,
          players: List.from(_players),
          isHost: true,
          playerName: _playerName,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
              const Card(
                color: Colors.orange,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Подключение...'),
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
                  ? const Center(
                      child: Text('Ожидание игроков...',
                          style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                      itemCount: _players.length,
                      itemBuilder: (context, index) => Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.primaries[index % Colors.primaries.length],
                            child: Text('${index + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(_players[index]),
                          trailing: _players[index] == _playerName
                              ? const Chip(label: Text('ВЫ'), backgroundColor: Colors.green)
                              : index == 0
                                  ? const Chip(label: Text('ХОСТ'), backgroundColor: Colors.blue)
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
                  child: FilledButton.icon(
                    onPressed: _players.length >= 2 ? _startGame : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_players.length >= 2
                        ? 'Начать игру'
                        : 'Ожидайте игроков (минимум 2)'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
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
    if (widget.isHost) _server.stop();
    super.dispose();
  }
}
EOF

echo "✅ Сетевая игра готова!"
echo "Запустите: git add -A && git commit -m 'Сетевая игра Уно через WebSocket' && git push"
