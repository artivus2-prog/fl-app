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
