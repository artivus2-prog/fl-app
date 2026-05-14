#!/bin/bash

# ========== Обновлённый card.dart ==========
cat > lib/models/card.dart << 'EOF'
import 'dart:math';
import 'package:flutter/material.dart';

enum CardColor { red, blue, green, yellow, wild }
enum CardType { number, skip, reverse, draw2, wild, wildDraw4, wildClear }

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
      case CardColor.red: return const Color(0xFFD50000);
      case CardColor.blue: return const Color(0xFF2962FF);
      case CardColor.green: return const Color(0xFF00C853);
      case CardColor.yellow: return const Color(0xFFFFD600);
      case CardColor.wild: return const Color(0xFF1A1A1A);
    }
  }

  Color get textColor {
    switch (color) {
      case CardColor.yellow: return Colors.black;
      default: return Colors.white;
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
      case CardType.wildClear: return '🧹';
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
    for (int i = 0; i < 8; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildClear));
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

# ========== Обновлённый home_screen.dart с кнопкой "Играть с ботами" ==========
cat > lib/screens/home_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'lobby_screen.dart';
import 'game_screen.dart';
import '../services/game_server.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0033), Color(0xFF0D001A), Color(0xFF1A0033)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип УНО
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(seconds: 2),
                  curve: Curves.elasticOut,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1744), Color(0xFFFF9100)],
                      ),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1744).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'УНО',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(2, 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Карточная игра',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 48),

                // Кнопка "Играть с ботами"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final server = GameServer();
                      final players = ['Вы', 'Бот 1', 'Бот 2', 'Бот 3'];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameScreen(
                            server: server,
                            players: players,
                            isHost: true,
                            playerName: 'Вы',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.computer, size: 24),
                    label: const Text('Играть с ботами'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF7C4DFF).withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Разделитель
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('ИЛИ', style: TextStyle(color: Colors.grey[500], letterSpacing: 2)),
                    ),
                    const Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 16),

                // Кнопка "Создать игру"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF00E676).withOpacity(0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Кнопка "Подключиться"
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final ipController = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          backgroundColor: const Color(0xFF1A1A2E),
                          title: const Row(
                            children: [
                              Icon(Icons.wifi, color: Color(0xFF448AFF)),
                              SizedBox(width: 12),
                              Text('Подключиться', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Введите IP адрес хоста', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: ipController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Например: 192.168.1.5',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  labelText: 'IP адрес',
                                  labelStyle: const TextStyle(color: Color(0xFF448AFF)),
                                  prefixIcon: const Icon(Icons.computer, color: Color(0xFF448AFF)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF448AFF))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF448AFF), width: 2)),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
                            ElevatedButton(
                              onPressed: () {
                                final ip = ipController.text.trim();
                                if (ip.isNotEmpty) {
                                  Navigator.pop(context);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(isHost: false, hostIp: ip)));
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF448AFF)),
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
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      foregroundColor: const Color(0xFF448AFF),
                      side: const BorderSide(color: Color(0xFF448AFF), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
EOF

# ========== Обновлённый game_screen.dart с красивыми картами ==========
cat > lib/screens/game_screen.dart << 'EOF'
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/bot_player.dart';
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

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late UnoGameState _gameState;
  late UnoDeck _deck;
  final BotPlayer _bot = BotPlayer();
  bool _isMyTurn = false;
  bool _gameStarted = false;
  String _direction = '➡️';
  final Set<String> _selectedCardIds = {};
  bool _multiSelectMode = false;
  bool _choosingColor = false;
  UnoCard? _pendingWildCard;
  Timer? _botTimer;
  bool _unoPressed = false;
  int _unoSecondsLeft = 10;
  Timer? _unoTimer;
  late AnimationController _pulseController;

  bool get _isBotTurn => _gameState.currentPlayer.startsWith('Бот');

  @override
  void initState() {
    super.initState();
    _deck = UnoDeck(seed: 42);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    widget.server.onMessage = (GameMessage message) => _handleMessage(message);
    if (widget.isHost) _startGameAsHost();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _unoTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
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
    _broadcastState();
  }

  void _broadcastState() {
    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.gameState,
      data: _gameState.toJson(),
    ));
  }

  void _handleMessage(GameMessage message) {
    if (!mounted) return;
    switch (message.type) {
      case GameMessageType.startGame:
      case GameMessageType.playCard:
      case GameMessageType.drawCard:
      case GameMessageType.gameState:
        setState(() {
          _gameState = UnoGameState.fromJson(message.data);
          _gameStarted = true;
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
    _selectedCardIds.clear();
    _multiSelectMode = false;
    _choosingColor = false;
    _pendingWildCard = null;
    _unoTimer?.cancel();
    _unoSecondsLeft = 10;
    _pulseController.stop();

    if (_gameState.winner != null && mounted) {
      _showWinDialog(_gameState.winner!);
      return;
    }

    final currentHand = _gameState.currentHand(_gameState.currentPlayer);
    if (currentHand.length == 2 && _gameState.currentPlayer == widget.playerName) {
      _unoPressed = false;
      _pulseController.repeat(reverse: true);
    }

    if (_isBotTurn && widget.isHost) {
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(milliseconds: 800), _botMove);
    }
  }

  void _applyClearCardEffect(CardColor chosenColor) {
    int totalCleared = 0;
    for (var player in _gameState.playerOrder) {
      final hand = _gameState.playerHands[player] ?? [];
      final toRemove = hand.where((c) => c.color == chosenColor).toList();
      totalCleared += toRemove.length;
      for (var card in toRemove) {
        _gameState.playerHands[player]!.removeWhere((c) => c.id == card.id);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🧹 Сброшено $totalCleared карт цвета ${_colorName(chosenColor)}!'), backgroundColor: _getColorForCard(chosenColor), duration: const Duration(seconds: 3)),
      );
    }
    for (var player in _gameState.playerOrder) {
      if (_gameState.playerHands[player]!.isEmpty && _gameState.winner == null) {
        _gameState.winner = player;
      }
    }
  }

  String _colorName(CardColor color) {
    switch (color) {
      case CardColor.red: return 'КРАСНЫЙ';
      case CardColor.blue: return 'СИНИЙ';
      case CardColor.green: return 'ЗЕЛЁНЫЙ';
      case CardColor.yellow: return 'ЖЁЛТЫЙ';
      case CardColor.wild: return 'ДИКИЙ';
    }
  }

  void _applyUnoPenalty(String player) {
    if (_gameState.playerHands[player]!.length == 1 && !_unoPressed) {
      setState(() {
        _gameState.playerHands[player]!.addAll(_deck.drawMultiple(2));
        _gameState.drawPileCount = _deck.cards.length;
      });
      _showUnoPenaltyMessage(player);
    }
  }

  void _showUnoPenaltyMessage(String player) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(player == widget.playerName ? '⚠️ Вы не нажали УНО! Штраф +2 карты!' : '⚠️ $player не нажал УНО! Штраф +2 карты!'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
    );
  }

  void _pressUno() {
    setState(() => _unoPressed = true);
    _pulseController.stop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ УНО!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
  }

  void _botMove() {
    if (!mounted || !_isBotTurn || !widget.isHost) return;
    final botName = _gameState.currentPlayer;
    final botHand = _gameState.currentHand(botName);
    final topCard = _gameState.topCard;
    final chosenColor = _gameState.chosenColor;
    final botUnoPressed = botHand.length == 2;

    if (_gameState.pendingResponsePlayer == botName) {
      if (_bot.shouldRespondToDraw4(botHand, chosenColor!)) {
        final draw2 = botHand.firstWhere((c) => c.type == CardType.draw2 && c.color == chosenColor);
        _gameState.playerHands[botName]!.removeWhere((c) => c.id == draw2.id);
        _gameState.discardPile.add(draw2);
        final prevIndex = _gameState.isClockwise ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
        _gameState.playerHands[_gameState.playerOrder[prevIndex]]!.addAll(_deck.drawMultiple(6));
        _gameState.pendingResponsePlayer = null;
      } else {
        _gameState.playerHands[botName]!.addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 4));
        _gameState.pendingResponsePlayer = null;
      }
      _gameState.nextTurn();
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    final chosenCard = _bot.chooseCard(botHand, topCard, chosenColor);
    if (chosenCard == null) {
      _gameState.playerHands[botName]!.add(_deck.draw());
      _gameState.drawPileCount = _deck.cards.length;
      _gameState.nextTurn();
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    _gameState.playerHands[botName]!.removeWhere((c) => c.id == chosenCard.id);
    _gameState.discardPile.add(chosenCard);

    if (botUnoPressed && _gameState.playerHands[botName]!.length == 1) {
      // ok
    } else if (botHand.length == 2 && !botUnoPressed) {
      _gameState.playerHands[botName]!.addAll(_deck.drawMultiple(2));
    }

    if (chosenCard.color == CardColor.wild) _gameState.chosenColor = _bot.chooseColor(botHand);

    if (chosenCard.type == CardType.wildClear) {
      _applyClearCardEffect(_gameState.chosenColor!);
    } else if (chosenCard.type == CardType.wildDraw4) {
      _handleWildDraw4(chosenCard);
    } else {
      _applyCardEffect(chosenCard);
    }

    if (_gameState.playerHands[botName]!.isEmpty) _gameState.winner = botName;
    if (chosenCard.type != CardType.wildDraw4 || _gameState.pendingResponsePlayer == null) _gameState.nextTurn();
    setState(() => _updateTurn());
    _broadcastState();
    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
  }

  void _playCard(UnoCard card) {
    if (!_isMyTurn || !_gameStarted) return;
    if (!card.canPlayOn(_gameState.topCard)) return;
    if (card.color == CardColor.wild) { setState(() { _choosingColor = true; _pendingWildCard = card; }); return; }
    final multiCards = _getMultiPlayableCards();
    if (multiCards.isNotEmpty && card.type == CardType.number) { setState(() { _multiSelectMode = true; _selectedCardIds.add(card.id); }); return; }
    _executePlayCard([card]);
  }

  void _onColorChosen(CardColor color) {
    if (_pendingWildCard == null) return;
    setState(() { _choosingColor = false; _gameState.chosenColor = color; });
    _executePlayCard([_pendingWildCard!]);
  }

  void _confirmMultiPlay() {
    if (_selectedCardIds.isEmpty) return;
    _executePlayCard(_gameState.currentHand(widget.playerName).where((c) => _selectedCardIds.contains(c.id)).toList());
  }

  void _executePlayCard(List<UnoCard> cards) {
    if (cards.isEmpty) return;
    final lastCard = cards.last;
    final handBefore = _gameState.currentHand(widget.playerName).length;
    for (var card in cards) _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
    _gameState.discardPile.add(lastCard);
    if (handBefore == 2 && _gameState.currentHand(widget.playerName).length == 1 && !_unoPressed) _applyUnoPenalty(widget.playerName);
    if (lastCard.type == CardType.wildClear) _applyClearCardEffect(_gameState.chosenColor!);
    else if (lastCard.type == CardType.wildDraw4) _handleWildDraw4(lastCard);
    else _applyCardEffect(lastCard);
    if (_gameState.playerHands[widget.playerName]!.isEmpty) _gameState.winner = widget.playerName;
    if (lastCard.type != CardType.wildDraw4 || _gameState.pendingResponsePlayer == null) _gameState.nextTurn();
    _updateTurn();
    _broadcastState();
    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
  }

  void _handleWildDraw4(UnoCard wildCard) {
    final nextIndex = _gameState.isClockwise ? (_gameState.currentPlayerIndex + 1) % _gameState.playerCount : (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount;
    final nextPlayer = _gameState.playerOrder[nextIndex];
    final nextHand = _gameState.playerHands[nextPlayer] ?? [];
    final chosenColor = _gameState.chosenColor;
    if (chosenColor == null) return;
    final hasDraw2 = nextHand.any((c) => c.type == CardType.draw2 && c.color == chosenColor);
    final hasOnlyDraw2 = hasDraw2 && nextHand.length == 1;
    if (hasOnlyDraw2) { _gameState.winner = nextPlayer; _gameState.playerHands[nextPlayer]!.clear(); return; }
    if (hasDraw2) { _gameState.pendingResponsePlayer = nextPlayer; _gameState.pendingDrawCount = 6; return; }
    _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(4));
  }

  void _respondToDraw4(UnoCard draw2Card) {
    _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == draw2Card.id);
    _gameState.discardPile.add(draw2Card);
    final prevIndex = _gameState.isClockwise ? (_gameState.currentPlayerIndex - 1 + _gameState.playerCount) % _gameState.playerCount : (_gameState.currentPlayerIndex + 1) % _gameState.playerCount;
    _gameState.playerHands[_gameState.playerOrder[prevIndex]]!.addAll(_deck.drawMultiple(6));
    _gameState.pendingResponsePlayer = null;
    _gameState.nextTurn();
    _updateTurn();
    _broadcastState();
  }

  void _applyCardEffect(UnoCard card) {
    switch (card.type) {
      case CardType.skip: _gameState.nextTurn(); break;
      case CardType.reverse: _gameState.isClockwise = !_gameState.isClockwise; if (_gameState.playerCount == 2) _gameState.nextTurn(); break;
      case CardType.draw2: _gameState.nextTurn(); _gameState.playerHands[_gameState.currentPlayer]!.addAll(_deck.drawMultiple(2)); break;
      default: break;
    }
  }

  void _drawCard() {
    if (!_isMyTurn && _gameState.pendingResponsePlayer != widget.playerName) return;
    if (!_gameStarted) return;
    if (_gameState.pendingResponsePlayer == widget.playerName) {
      _gameState.playerHands[widget.playerName]!.addAll(_deck.drawMultiple(_gameState.pendingDrawCount ?? 4));
      _gameState.pendingResponsePlayer = null;
    } else {
      _gameState.playerHands[widget.playerName]!.add(_deck.draw());
    }
    _gameState.drawPileCount = _deck.cards.length;
    _gameState.nextTurn();
    _updateTurn();
    _broadcastState();
  }

  List<UnoCard> _getMultiPlayableCards() {
    if (!_isMyTurn) return [];
    final hand = _gameState.currentHand(widget.playerName);
    final topCard = _gameState.topCard;
    Map<String, List<UnoCard>> groups = {};
    for (var card in hand) {
      if (card.type == CardType.number && card.canPlayOn(topCard)) {
        groups.putIfAbsent('${card.number}', () => []);
        groups['${card.number}']!.add(card);
      }
    }
    for (var group in groups.values) { if (group.length >= 2) return group; }
    return [];
  }

  void _toggleCardSelection(UnoCard card) {
    if (!_multiSelectMode) return;
    setState(() { _selectedCardIds.contains(card.id) ? _selectedCardIds.remove(card.id) : _selectedCardIds.add(card.id); });
  }

  void _showWinDialog(String winner) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(children: [const Text('🎉', style: TextStyle(fontSize: 32)), const SizedBox(width: 12), Text(winner == widget.playerName ? 'Вы победили!' : 'Победа!', style: const TextStyle(color: Colors.white))]),
        content: Text(winner == widget.playerName ? 'Отличная игра! Вы выиграли!' : '$winner выиграл игру!', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); widget.server.stop(); Navigator.pop(context); }, child: const Text('В меню', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); if (widget.isHost) { setState(() { _deck = UnoDeck(seed: Random().nextInt(99999)); _startGameAsHost(); }); } },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
            child: const Text('Играть снова'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    if (!_choosingColor) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(children: [Icon(Icons.palette, color: Colors.purple), SizedBox(width: 12), Text('Выберите цвет', style: TextStyle(color: Colors.white))]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_pendingWildCard?.type == CardType.wildClear ? 'Сброс цвета — все карты этого цвета будут сброшены!' : 'Дикая карта — выберите следующий цвет:', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _colorButton(CardColor.red, 'Красный', ctx),
            _colorButton(CardColor.blue, 'Синий', ctx),
            _colorButton(CardColor.green, 'Зелёный', ctx),
            _colorButton(CardColor.yellow, 'Жёлтый', ctx),
          ]),
        ]),
      ),
    );
  }

  Widget _colorButton(CardColor color, String label, BuildContext ctx) {
    Color c;
    switch (color) { case CardColor.red: c = Colors.red; break; case CardColor.blue: c = Colors.blue; break; case CardColor.green: c = Colors.green; break; case CardColor.yellow: c = Colors.amber; break; default: c = Colors.grey; }
    return GestureDetector(
      onTap: () { Navigator.pop(ctx); _onColorChosen(color); },
      child: Column(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)])),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_choosingColor) WidgetsBinding.instance.addPostFrameCallback((_) => _showColorPicker());
    if (!_gameStarted) return Scaffold(backgroundColor: const Color(0xFF0A0A1A), body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Color(0xFF7C4DFF)), SizedBox(height: 24), Text('Ожидание начала игры...', style: TextStyle(color: Colors.white, fontSize: 18))])));

    final myHand = _gameState.currentHand(widget.playerName);
    final isPendingResponse = _gameState.pendingResponsePlayer == widget.playerName;
    final showUnoButton = myHand.length == 2 && _isMyTurn && !_unoPressed;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [const Text('Уно ', style: TextStyle(color: Colors.white)), Text(_direction, style: const TextStyle(fontSize: 20))]),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.white70), onPressed: () { widget.server.stop(); Navigator.pop(context); }),
        actions: [
          if (_isBotTurn) const Padding(padding: EdgeInsets.only(right: 8), child: Chip(label: Text('БОТ ДУМАЕТ...', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Color(0xFF7C4DFF), avatar: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
          if (isPendingResponse) const Padding(padding: EdgeInsets.only(right: 8), child: Chip(label: Text('ОТВЕТЬТЕ!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange)),
          if (_isMyTurn && !isPendingResponse) const Padding(padding: EdgeInsets.only(right: 8), child: Chip(label: Text('ВАШ ХОД', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF00E676), avatar: Icon(Icons.play_arrow, size: 16))),
        ],
      ),
      body: Column(children: [
        if (showUnoButton || (_unoPressed && myHand.length == 1))
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Container(
              padding: const EdgeInsets.all(12), margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _unoPressed ? [Colors.green, Colors.greenAccent] : [Colors.red, Colors.deepOrange]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3 + _pulseController.value * 0.3), blurRadius: 12 + _pulseController.value * 10)],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (!_unoPressed && myHand.length == 2) ...[
                  const Icon(Icons.warning, color: Colors.white, size: 28), const SizedBox(width: 12),
                  Expanded(child: Column(children: [const Text('НАЖМИТЕ УНО!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)), Text('$_unoSecondsLeft сек до штрафа', style: const TextStyle(color: Colors.white70, fontSize: 14))])), const SizedBox(width: 12),
                  SizedBox(height: 48, child: ElevatedButton(onPressed: _pressUno, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 24)), child: const Text('УНО!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)))),
                ] else ...[
                  const Icon(Icons.check_circle, color: Colors.white, size: 24), const SizedBox(width: 8), const Text('УНО принято!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ]),
            ),
          ),
        Expanded(flex: 2, child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: (_isMyTurn || isPendingResponse) ? _drawCard : null,
            child: _buildDeckCard(),
          ),
          const SizedBox(width: 24),
          _buildCardWidget(_gameState.topCard, big: true),
        ]))),
        Container(height: 50, margin: const EdgeInsets.symmetric(horizontal: 8), child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: widget.players.length, itemBuilder: (context, index) {
          final player = widget.players[index];
          final isCurrent = player == _gameState.currentPlayer;
          final cardCount = _gameState.playerHands[player]?.length ?? 0;
          return Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: isCurrent ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: isCurrent ? Border.all(color: Colors.greenAccent, width: 2) : Border.all(color: Colors.white12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(player.startsWith('Бот') ? Icons.computer : Icons.person, size: 14, color: player == widget.playerName ? Colors.amber : Colors.white70), const SizedBox(width: 4), Text(player, style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)), const SizedBox(width: 4), Text('$cardCount🃏', style: const TextStyle(fontSize: 10, color: Colors.white70))]));
        })),
        if (_multiSelectMode) Container(padding: const EdgeInsets.all(8), color: Colors.amber.withOpacity(0.2), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.touch_app, size: 18, color: Colors.amber), SizedBox(width: 8), Text('Выберите одинаковые карты для сброса', style: TextStyle(color: Colors.amber, fontSize: 13))])),
        if (isPendingResponse) Container(padding: const EdgeInsets.all(8), color: Colors.orange.withOpacity(0.2), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.warning, size: 18, color: Colors.orange), SizedBox(width: 8), Text('Ответьте своей +2 или возьмите 6 карт!', style: TextStyle(color: Colors.orange, fontSize: 13))])),
        const SizedBox(height: 4),
        if (_multiSelectMode && _selectedCardIds.length >= 2) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _confirmMultiPlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Сбросить выбранные карты', style: TextStyle(fontWeight: FontWeight.bold))))),
        Expanded(flex: 3, child: myHand.isEmpty ? const Center(child: Text('У вас нет карт!', style: TextStyle(fontSize: 18, color: Colors.white38))) : SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: myHand.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          final canPlay = _isMyTurn && card.canPlayOn(_gameState.topCard);
          final isPendingDraw2 = isPendingResponse && card.type == CardType.draw2 && card.color == _gameState.chosenColor;
          final isSelected = _selectedCardIds.contains(card.id);
          final canTap = canPlay || isPendingDraw2;
          return GestureDetector(
            onTap: () {
              if (isPendingDraw2) _respondToDraw4(card);
              else if (_multiSelectMode && card.type == CardType.number && canPlay) _toggleCardSelection(card);
              else if (canTap) _playCard(card);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(top: (canTap || isPendingDraw2) ? 0 : 15, bottom: isSelected ? 15 : 0),
                decoration: isSelected ? BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.8), blurRadius: 16, spreadRadius: 3)]) : null,
                child: Opacity(opacity: (canTap || isPendingDraw2) ? 1.0 : 0.5, child: Stack(children: [
                  _buildCardWidget(card),
                  if (isPendingDraw2) Positioned(top: -5, right: -5, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.reply, size: 16, color: Colors.white))),
                  if (isSelected) const Positioned(top: -5, left: -5, child: Icon(Icons.check_circle, color: Colors.amber, size: 22)),
                ])),
              ),
            ),
          );
        }).toList()))),
      ]),
    );
  }

  Widget _buildDeckCard() {
    return Container(
      width: 75, height: 110,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF333333)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10, offset: const Offset(3, 4))],
      ),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('УНО', style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
          const SizedBox(height: 4),
          Container(width: 40, height: 3, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue]), borderRadius: BorderRadius.all(Radius.circular(2)))),
        ]),
      ),
    );
  }

  Widget _buildCardWidget(UnoCard card, {bool big = false}) {
    final w = big ? 105.0 : 75.0;
    final h = big ? 155.0 : 110.0;
    final isWild = card.color == CardColor.wild;
    final isClear = card.type == CardType.wildClear;
    final bgColor = isClear ? const Color(0xFF6A1B9A) : card.displayColor;
    final txtColor = (card.color == CardColor.yellow || isClear) ? Colors.black : Colors.white;

    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8, offset: const Offset(2, 4))],
      ),
      child: Stack(
        children: [
          // Белый овал в центре (как в настоящем УНО)
          if (!isWild && !isClear)
            Center(
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  width: w * 0.7, height: h * 0.55,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),
          // Текст карты
          Center(
            child: Text(
              card.displayText,
              style: TextStyle(
                fontSize: big ? 48 : 34,
                fontWeight: FontWeight.w900,
                color: txtColor,
                shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(1, 2))],
              ),
            ),
          ),
          // Уголок с цифрой/символом
          if (card.type == CardType.number)
            Positioned(
              top: 6, left: 10,
              child: Text('${card.number}', style: TextStyle(fontSize: big ? 20 : 14, fontWeight: FontWeight.w900, color: txtColor)),
            ),
          // Радужная полоса для диких
          if (isWild || isClear)
            Positioned(
              bottom: 0, left: 4, right: 4,
              child: Container(height: 5, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)))),
            ),
        ],
      ),
    );
  }

  Color _getColorForCard(CardColor color) {
    switch (color) {
      case CardColor.red: return Colors.red;
      case CardColor.blue: return Colors.blue;
      case CardColor.green: return Colors.green;
      case CardColor.yellow: return Colors.amber;
      case CardColor.wild: return Colors.purple;
    }
  }
}
EOF

echo "✅ Дизайн обновлён!"
echo "  - Карты с белым овалом (как в настоящем УНО)"
echo "  - Кнопка 'Играть с ботами' на главном экране"
echo "  - Тёмная тема с фиолетовыми акцентами"
echo "  - Анимированная кнопка УНО"
echo "  - Уголки с цифрами на картах"
echo "Запустите: git add -A && git commit -m 'Новый дизайн карт и кнопка Играть с ботами' && git push"
