// lib/services/game_server.dart

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
      data: map['data'] ?? {},
      fromPlayer: map['fromPlayer'],
    );
  }
}

class GameServer {
  WebSocket? _socket;
  final List<String> _players = [];
  String _playerName = '';
  String? _roomId;
  String? _connectionId;
  Function(GameMessage)? onMessage;
  Function(String)? onConnected;
  Function(String)? onDisconnected;
  Function(List<String>)? onPlayerListChanged;
  
  // Для хоста
  final List<WebSocket> _clients = [];
  bool _isHost = false;
  
  bool get isConnected => _socket != null;
  List<String> get players => List.unmodifiable(_players);
  String get playerName => _playerName;
  String? get roomId => _roomId;

  String _generateClientId() {
    return 'client_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
  }
  
  // ⭐ СОЗДАНИЕ КОМНАТЫ (локальный сервер)
  Future<bool> createRoom(String playerName) async {
    _playerName = playerName;
    _connectionId = _generateClientId();
    _isHost = true;
    
    try {
      // Локальный сервер
      final url = 'ws://192.168.1.151:6000/ws/${_connectionId}';
      debugPrint('🔌 Подключение к локальному серверу: $url');
      
      _socket = await WebSocket.connect(url);
      _socket!.listen(_handleMessage, onDone: _handleDisconnect, onError: _handleError);
      
      _send({
        'type': 'create_room',
        'playerName': playerName,
      });
      
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка подключения: $e');
      return false;
    }
  }
  
  // ⭐ ПОДКЛЮЧЕНИЕ К КОМНАТЕ (локальный сервер)
  Future<bool> joinRoom(String roomId, String playerName) async {
    _playerName = playerName;
    _roomId = roomId;
    _connectionId = _generateClientId();
    _isHost = false;
    
    try {
      final url = 'ws://192.168.1.151:6000/ws/${_connectionId}';
      debugPrint('🔌 Подключение к локальному серверу: $url');
      
      _socket = await WebSocket.connect(url);
      _socket!.listen(_handleMessage, onDone: _handleDisconnect, onError: _handleError);
      
      _send({
        'type': 'join_room',
        'roomId': roomId,
        'playerName': playerName,
      });
      
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка подключения: $e');
      return false;
    }
  }
  
  void broadcastAll(GameMessage message) {
    if (_isHost) {
      final json = message.toJson();
      for (var client in _clients) {
        client.add(json);
      }
    }
    if (onMessage != null) onMessage!(message);
  }
  
  void startGame() {
    _send({'type': 'start_game'});
  }
  
  void sendGameState(Map<String, dynamic> gameState) {
    _send({
      'type': 'game_state',
      'data': gameState,
    });
  }
  
  void sendChatMessage(String player, String message) {
    _send({
      'type': 'chat',
      'player': player,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  void leaveRoom() {
    _send({'type': 'leave_room'});
    _closeSocket();
  }
  
  void _send(Map<String, dynamic> message) {
    if (_socket != null) {
      _socket!.add(jsonEncode(message));
    }
  }
  
  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> json = jsonDecode(data as String);
      final type = json['type'] as String;
      
      debugPrint('📨 Получено: $type');
      
      switch (type) {
        case 'connected':
          debugPrint('✅ Соединение установлено');
          break;
          
        case 'room_created':
          _roomId = json['room_id'];
          _players.clear();
          _players.addAll(List<String>.from(json['players']));
          if (onConnected != null) onConnected!(_roomId!);
          if (onPlayerListChanged != null) onPlayerListChanged!(_players);
          break;
          
        case 'joined':
          _roomId = json['room_id'];
          _players.clear();
          _players.addAll(List<String>.from(json['players']));
          if (onConnected != null) onConnected!(_roomId!);
          if (onPlayerListChanged != null) onPlayerListChanged!(_players);
          break;
          
        case 'player_list':
          _players.clear();
          _players.addAll(List<String>.from(json['players']));
          if (onPlayerListChanged != null) onPlayerListChanged!(_players);
          break;
          
        case 'start_game':
          if (onMessage != null) {
            onMessage!(GameMessage(
              type: GameMessageType.startGame,
              data: {'players': json['players']},
            ));
          }
          break;
          
        case 'game_state':
          if (onMessage != null) {
            onMessage!(GameMessage(
              type: GameMessageType.gameState,
              data: json['data'] ?? {},
            ));
          }
          break;
          
        case 'chat':
          if (onMessage != null) {
            onMessage!(GameMessage(
              type: GameMessageType.chat,
              data: {
                'player': json['player'],
                'message': json['message'],
                'timestamp': json['timestamp'],
              },
            ));
          }
          break;
          
        case 'pong':
          break;
          
        case 'error':
          debugPrint('❌ Ошибка: ${json['message']}');
          break;
          
        default:
          debugPrint('⚠️ Неизвестный тип: $type');
      }
    } catch (e) {
      debugPrint('❌ Ошибка парсинга: $e');
    }
  }
  
  void _handleDisconnect() {
    debugPrint('🔌 Соединение разорвано');
    _closeSocket();
    if (onDisconnected != null) onDisconnected!('Соединение потеряно');
  }
  
  void _handleError(dynamic error) {
    debugPrint('❌ Ошибка: $error');
    _closeSocket();
    if (onDisconnected != null) onDisconnected!('Ошибка: $error');
  }
  
  void _closeSocket() {
    _socket?.close();
    _socket = null;
    _clients.clear();
  }
  
  void stop() {
    _closeSocket();
  }
  
  void startPing() {
    Future.delayed(const Duration(seconds: 30), _pingLoop);
  }
  
  void _pingLoop() {
    if (_socket != null) {
      _send({'type': 'ping'});
      Future.delayed(const Duration(seconds: 30), _pingLoop);
    }
  }
}