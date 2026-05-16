import 'package:flutter/material.dart';
import '../services/game_server.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final bool isHost;
  final String? hostIp;
  final String? roomId;

  const LobbyScreen({super.key, required this.isHost, this.hostIp, this.roomId});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final GameServer _server = GameServer();
  final List<String> _players = [];
  String? _roomId;
  bool _connected = false;
  String _playerName = '';
  String _connectionStatus = 'Подключение...';

  @override
  void initState() {
    super.initState();
    _playerName = widget.isHost ? 'Хост' : 'Гость';
    _setupServer();
  }

  Future<void> _setupServer() async {
    _server.onMessage = (GameMessage message) {
      if (message.type == GameMessageType.startGame && mounted) {
        _navigateToGame();
      }
    };
    
    _server.onPlayerListChanged = (players) {
      if (mounted) {
        setState(() {
          _players.clear();
          _players.addAll(players);
        });
      }
    };
    
    _server.onConnected = (roomId) {
      if (mounted) {
        setState(() {
          _roomId = roomId;
          _connected = true;
          _connectionStatus = 'Подключено';
        });
      }
    };
    
    _server.onDisconnected = (message) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionStatus = message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    };
    
    bool success;
    if (widget.isHost) {
      success = await _server.createRoom(_playerName);
    } else {
      if (widget.roomId != null) {
        success = await _server.joinRoom(widget.roomId!, _playerName);
      } else {
        success = false;
        _connectionStatus = 'ID комнаты не указан';
      }
    }
    
    if (!success && mounted) {
      setState(() {
        _connectionStatus = 'Ошибка подключения';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось подключиться к серверу'), backgroundColor: Colors.red),
      );
    }
    
    _server.startPing();
  }

  void _navigateToGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          server: _server,
          players: List.from(_players),
          isHost: widget.isHost,
          playerName: _playerName,
        ),
      ),
    );
  }

  void _startGame() {
    if (_players.length >= 2) {
      _server.startGame();
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
            if (!_connected) ...[
              Card(
                color: Colors.orange.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_connectionStatus, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            if (widget.isHost && _connected && _roomId != null) ...[
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
                          Text('ID комнаты', style: TextStyle(fontSize: 16, color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _roomId!,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                      const SizedBox(height: 8),
                      const Text('Скажите этот код друзьям для подключения',
                          style: TextStyle(color: Colors.grey)),
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
            if (widget.isHost && _connected)
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
    _server.stop();
    super.dispose();
  }
}