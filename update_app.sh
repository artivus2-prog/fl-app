#!/bin/bash

# Создаём папки
mkdir -p lib/screens lib/models lib/services

# ========== main.dart ==========
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const UnoApp());
}

class UnoApp extends StatelessWidget {
  const UnoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Уно',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
EOF

# ========== models/card.dart ==========
cat > lib/models/card.dart << 'EOF'
enum CardColor { red, blue, green, yellow, wild }
enum CardType { number, skip, reverse, draw2, wild, wildDraw4 }

class UnoCard {
  final CardColor color;
  final CardType type;
  final int? number;

  const UnoCard({required this.color, required this.type, this.number});

  bool canPlayOn(UnoCard topCard) {
    if (color == CardColor.wild) return true;
    if (topCard.color == color) return true;
    if (topCard.type == type && type == CardType.number) {
      return topCard.number == number;
    }
    if (topCard.type == type && type != CardType.number) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'color': color.name,
        'type': type.name,
        'number': number,
      };

  factory UnoCard.fromJson(Map<String, dynamic> json) => UnoCard(
        color: CardColor.values.byName(json['color']),
        type: CardType.values.byName(json['type']),
        number: json['number'],
      );
}
EOF

# ========== services/game_server.dart ==========
cat > lib/services/game_server.dart << 'EOF'
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum GameMessageType {
  join, playerList, startGame, playCard, drawCard, gameState, chat,
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
  final List<WebSocket> _clients = [];
  final List<String> _players = [];
  final int port;

  GameServer({this.port = 8080});

  bool get isHosting => _server != null;
  List<String> get players => List.unmodifiable(_players);

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

  Future<void> startHost(VoidCallback onPlayerJoined) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    debugPrint('Сервер запущен на порту $port');

    _server!.listen((HttpRequest request) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocketTransformer.upgrade(request).then((WebSocket socket) {
          _clients.add(socket);
          _players.add('Игрок ${_players.length + 1}');

          _broadcast(GameMessage(
            type: GameMessageType.playerList,
            data: {'players': _players},
          ));

          onPlayerJoined();

          socket.listen((data) {
            final message = GameMessage.fromJson(data);
            _handleMessage(message, socket);
          }, onDone: () {
            _clients.remove(socket);
            _players.removeAt(_clients.indexOf(socket));
            _broadcast(GameMessage(
              type: GameMessageType.playerList,
              data: {'players': _players},
            ));
          });
        });
      }
    });
  }

  Future<WebSocket> connectToHost(String ip) async {
    final socket = await WebSocket.connect('ws://$ip:$port');
    _clients.add(socket);
    return socket;
  }

  void _handleMessage(GameMessage message, WebSocket sender) {
    for (var client in _clients) {
      if (client != sender) {
        client.add(message.toJson());
      }
    }
  }

  void _broadcast(GameMessage message) {
    final json = message.toJson();
    for (var client in _clients) {
      client.add(json);
    }
  }

  void sendMessage(GameMessage message) {
    _broadcast(message);
  }

  void stopServer() {
    for (var client in _clients) {
      client.close();
    }
    _server?.close();
    _server = null;
    _clients.clear();
    _players.clear();
  }
}
EOF

# ========== screens/home_screen.dart ==========
cat > lib/screens/home_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    'УНО',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LobbyScreen(isHost: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  label: const Text('Создать игру'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.grey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('ИЛИ', style: TextStyle(color: Colors.grey[500])),
                  ),
                  const Expanded(child: Divider(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final ipController = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Row(
                          children: [
                            Icon(Icons.wifi, color: Colors.blue),
                            SizedBox(width: 12),
                            Text('Подключиться'),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Введите IP адрес хоста',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: ipController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Например: 192.168.1.5',
                                labelText: 'IP адрес',
                                prefixIcon: const Icon(Icons.computer),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final ip = ipController.text.trim();
                              if (ip.isNotEmpty) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LobbyScreen(
                                      isHost: false,
                                      hostIp: ip,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text('Подключиться'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.wifi, size: 24),
                  label: const Text('Подключиться к игре'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
EOF

# ========== screens/lobby_screen.dart ==========
cat > lib/screens/lobby_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import '../services/game_server.dart';

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
                    onPressed: _players.length >= 2
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Игра начинается!')),
                            );
                          }
                        : null,
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

# ========== test/widget_test.dart ==========
cat > test/widget_test.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_app/screens/home_screen.dart';

void main() {
  testWidgets('Главный экран: есть кнопки', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Создать игру'), findsOneWidget);
    expect(find.text('Подключиться к игре'), findsOneWidget);
    expect(find.text('УНО'), findsOneWidget);
  });
}
EOF

# Удаляем старые файлы
rm -f lib/widgets/globe_widget.dart lib/widgets/start_button.dart
rmdir lib/widgets 2>/dev/null || true

echo "✅ Готово! Все файлы созданы."
echo "Запустите: git add -A && git commit -m 'Игра Уно: лобби и подключение' && git push"
