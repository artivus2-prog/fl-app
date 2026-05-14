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
