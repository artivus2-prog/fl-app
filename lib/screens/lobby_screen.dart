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
