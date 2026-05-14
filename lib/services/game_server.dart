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
