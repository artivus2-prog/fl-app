import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/bot_player.dart';
import '../services/game_server.dart';
import 'settings_screen.dart';

// ========== АНИМИРОВАННЫЕ КОМПОНЕНТЫ ==========

class AnimatedCard extends StatefulWidget {
  final UnoCard card;
  final bool isBig;
  final bool isSelected;
  final bool canTap;
  final VoidCallback onTap;
  final bool isDiscard;

  const AnimatedCard({
    super.key,
    required this.card,
    this.isBig = false,
    this.isSelected = false,
    this.canTap = true,
    required this.onTap,
    this.isDiscard = false,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
    
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(begin: 1, end: 1.1).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isDiscard) {
      _flipController.forward();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void animateTap() {
    _scaleController.forward().then((_) => _scaleController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.canTap) {
          animateTap();
          widget.onTap();
        }
      },
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isFlipped = _flipAnimation.value > 0.5;
          final angle = _flipAnimation.value * 3.14159;
          
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: (isFlipped && widget.isDiscard) 
                ? const SizedBox.shrink()
                : Transform.scale(
                    scale: widget.isSelected ? 1.05 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: widget.isSelected ? [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.8),
                            blurRadius: 16,
                            spreadRadius: 3,
                          ),
                        ] : null,
                      ),
                      child: _buildCardContent(),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardContent() {
    final w = widget.isBig ? 100.0 : 85.0;
    final h = widget.isBig ? 145.0 : 120.0;
    final isWild = widget.card.color == CardColor.wild;
    final isClear = widget.card.type == CardType.clear;
    final bgColor = widget.card.displayColor;
    final txtColor = (widget.card.color == CardColor.yellow) ? Colors.black : Colors.white;
    
    String displayText = '';
    switch (widget.card.type) {
      case CardType.number:
        displayText = '${widget.card.number}';
        break;
      case CardType.skip:
        displayText = '⊘';
        break;
      case CardType.reverse:
        displayText = '⟲';
        break;
      case CardType.draw2:
        displayText = '+2';
        break;
      case CardType.wild:
        displayText = 'W';
        break;
      case CardType.wildDraw4:
        displayText = '+4';
        break;
      case CardType.wildDraw8:
        displayText = '+8';
        break;
      case CardType.clear:
        displayText = '🧹';
        break;
    }
    
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (!isWild && !isClear)
            Center(
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: w * 0.65,
                  height: h * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),
          if (isClear)
            Center(
              child: Icon(
                Icons.cleaning_services,
                size: widget.isBig ? 50 : 40,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          Center(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: widget.isBig ? 44 : 32,
                fontWeight: FontWeight.w900,
                color: txtColor,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
          if (widget.card.type == CardType.number)
            Positioned(
              top: 6,
              left: 10,
              child: Text(
                '${widget.card.number}',
                style: TextStyle(
                  fontSize: widget.isBig ? 18 : 14,
                  fontWeight: FontWeight.w900,
                  color: txtColor,
                ),
              ),
            ),
          if (isWild)
            Positioned(
              bottom: 0,
              left: 4,
              right: 4,
              child: Container(
                height: 6,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AnimatedDeck extends StatefulWidget {
  final bool canDraw;
  final int cardCount;
  final VoidCallback onTap;
  final bool isGlowing;

  const AnimatedDeck({
    super.key,
    required this.canDraw,
    required this.cardCount,
    required this.onTap,
    this.isGlowing = false,
  });

  @override
  State<AnimatedDeck> createState() => _AnimatedDeckState();
}

class _AnimatedDeckState extends State<AnimatedDeck> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseAnimation = Tween<double>(begin: 1, end: 1.1).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isGlowing) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGlowing && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isGlowing && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.canDraw ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isGlowing ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF333333)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isGlowing ? Colors.yellow : Colors.white.withOpacity(0.3),
                  width: widget.isGlowing ? 3 : 2,
                ),
                boxShadow: widget.isGlowing ? [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ] : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(3, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'УНО',
                          style: TextStyle(
                            color: Color(0xFFFF1744),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.cardCount}',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  if (widget.canDraw)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: const Text(
                        'Нажми, чтобы взять',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.yellow, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnimatedDiscardPile extends StatefulWidget {
  final UnoCard card;

  const AnimatedDiscardPile({super.key, required this.card});

  @override
  State<AnimatedDiscardPile> createState() => _AnimatedDiscardPileState();
}

class _AnimatedDiscardPileState extends State<AnimatedDiscardPile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    _rotationAnimation = Tween<double>(begin: -0.1, end: 0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedDiscardPile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..scale(_scaleAnimation.value)
            ..rotateZ(_rotationAnimation.value),
          alignment: Alignment.center,
          child: Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(3, 4),
                ),
              ],
            ),
            child: _buildCardContent(),
          ),
        );
      },
    );
  }

  Widget _buildCardContent() {
    final isWild = widget.card.color == CardColor.wild;
    final isClear = widget.card.type == CardType.clear;
    final bgColor = widget.card.displayColor;
    final txtColor = (widget.card.color == CardColor.yellow) ? Colors.black : Colors.white;
    
    String displayText = '';
    switch (widget.card.type) {
      case CardType.number:
        displayText = '${widget.card.number}';
        break;
      case CardType.skip:
        displayText = '⊘';
        break;
      case CardType.reverse:
        displayText = '⟲';
        break;
      case CardType.draw2:
        displayText = '+2';
        break;
      case CardType.wild:
        displayText = 'W';
        break;
      case CardType.wildDraw4:
        displayText = '+4';
        break;
      case CardType.wildDraw8:
        displayText = '+8';
        break;
      case CardType.clear:
        displayText = '🧹';
        break;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: Stack(
        children: [
          if (!isWild && !isClear)
            Center(
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: 65,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),
          if (isClear)
            Center(
              child: Icon(
                Icons.cleaning_services,
                size: 50,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          Center(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: txtColor,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
          if (isWild)
            Positioned(
              bottom: 0,
              left: 4,
              right: 4,
              child: Container(
                height: 6,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ========== ОСНОВНОЙ КЛАСС ИГРЫ ==========

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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late UnoGameState _gameState;
  late UnoDeck _deck;
  final BotPlayer _bot = BotPlayer();
  bool _isMyTurn = false;
  bool _gameStarted = false;
  String _direction = '➡️';
  final Set<String> _selectedCardIds = {};
  bool _multiSelectMode = false;
  bool _choosingColor = false;
  bool _isColorPickerShowing = false;
  UnoCard? _pendingWildCard;
  Timer? _botTimer;
  bool _unoPressed = false;
  bool _needUnoButton = false;
  int _unoSecondsLeft = 10;
  Timer? _unoTimer;
  late AnimationController _pulseController;
  Timer? _lastTapTimer;
  String? _lastTappedCardId;
  Color _backgroundColor = const Color(0xFF1B5E20);
  bool _choosingResponseColor = false;
  bool _isResponseColorPickerShowing = false;
  UnoCard? _pendingResponseCard;
  bool _isAnimating = false;
  
  // Чат
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatOpen = false;

  bool get _isBotTurn => _gameState.currentPlayer.startsWith('Бот');
  bool get _noPlayableCards {
    if (!_isMyTurn && _gameState.pendingResponsePlayer != widget.playerName) return false;
    return !_gameState.currentHand(widget.playerName)
        .any((c) => c.canPlayOn(_gameState.topCard, chosenColor: _gameState.chosenColor));
  }

  // ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ 2 ИГРОКОВ ==========
  
  int _getNextPlayerIndex(int currentIndex, bool isClockwise, int playerCount) {
    if (playerCount == 2) {
      return (currentIndex + 1) % 2;
    }
    return isClockwise 
        ? (currentIndex + 1) % playerCount 
        : (currentIndex - 1 + playerCount) % playerCount;
  }

  int _getPrevPlayerIndex(int currentIndex, bool isClockwise, int playerCount) {
    if (playerCount == 2) {
      return (currentIndex + 1) % 2;
    }
    return isClockwise 
        ? (currentIndex - 1 + playerCount) % playerCount 
        : (currentIndex + 1) % playerCount;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _deck = UnoDeck(seed: DateTime.now().millisecondsSinceEpoch);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    widget.server.onMessage = (GameMessage message) => _handleMessage(message);
    if (widget.isHost) _startGameAsHost();
    _loadBackground();
    
    _chatMessages.add(ChatMessage(
      playerName: 'Система',
      message: 'Добро пожаловать в игру!',
      isSystem: true,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _loadBackground() async {
    setState(() {
      _backgroundColor = SettingsScreenState.backgroundColor;
    });
  }

  void _sendChatMessage() {
    if (_chatController.text.trim().isEmpty) return;
    final message = _chatController.text.trim();
    _chatController.clear();
    
    widget.server.broadcastAll(GameMessage(
      type: GameMessageType.chat,
      data: {
        'player': widget.playerName,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      },
    ));
    
    _addChatMessage(ChatMessage(
      playerName: widget.playerName,
      message: message,
      isSystem: false,
      timestamp: DateTime.now(),
    ));
  }
  
  void _addChatMessage(ChatMessage message) {
    setState(() {
      _chatMessages.add(message);
    });
    _scrollToBottom();
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _botTimer?.cancel();
    _unoTimer?.cancel();
    _pulseController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _startGameAsHost() {
    _deck = UnoDeck(seed: DateTime.now().millisecondsSinceEpoch);
    
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
      pendingAttackCardType: null,
    );
    _gameStarted = true;
    _updateTurn();
    _broadcastState();
  }

  void _broadcastState() {
    widget.server.broadcastAll(GameMessage(type: GameMessageType.gameState, data: _gameState.toJson()));
  }

  void _handleMessage(GameMessage message) {
    if (!mounted) return;
    
    if (message.type == GameMessageType.chat) {
      _addChatMessage(ChatMessage(
        playerName: message.data['player'],
        message: message.data['message'],
        isSystem: false,
        timestamp: DateTime.parse(message.data['timestamp']),
      ));
      return;
    }
    
    setState(() {
      _gameState = UnoGameState.fromJson(message.data);
      _gameStarted = true;
      _updateTurn();
    });
  }

  void _startUnoTimer() {
    _unoTimer?.cancel();
    _unoSecondsLeft = 10;
    _unoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _unoSecondsLeft--;
        if (_unoSecondsLeft <= 0) {
          timer.cancel();
          if (!_unoPressed && _needUnoButton && 
              _gameState.currentHand(widget.playerName).length == 1) {
            _applyUnoPenalty(widget.playerName);
            _needUnoButton = false;
            _pulseController.stop();
          }
        }
      });
    });
  }

  void _updateTurn() {
    _isMyTurn = _gameState.currentPlayer == widget.playerName;
    _direction = _gameState.isClockwise ? '➡️' : '⬅️';
    _selectedCardIds.clear();
    _multiSelectMode = false;
    _choosingColor = false;
    _pendingWildCard = null;
    
    _unoTimer?.cancel();
    _pulseController.stop();
    
    if (_gameState.currentPlayer != widget.playerName) {
      _needUnoButton = false;
      _unoPressed = false;
    }
    
    if (_gameState.winner != null && mounted) {
      _showWinDialog(_gameState.winner!);
      return;
    }
    
    final top = _gameState.discardPile.isNotEmpty ? _gameState.discardPile.last : null;
    if (top == null || top.color != CardColor.wild) {
      _gameState.chosenColor = null;
    }
    
    final currentHand = _gameState.currentHand(_gameState.currentPlayer);
    // УНО только если это НЕ бот и нет pending ответа
    if (currentHand.length == 1 && 
        _gameState.currentPlayer == widget.playerName && 
        !_unoPressed &&
        _gameState.pendingResponsePlayer == null) {
      _needUnoButton = true;
      _pulseController.repeat(reverse: true);
      _startUnoTimer();
    } else {
      _needUnoButton = false;
    }
    
    if (_isBotTurn && widget.isHost) {
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(milliseconds: 800), _botMove);
    }
  }

  bool _canRespondToDraw(String player, CardColor chosenColor, CardType attackCardType) {
    final hand = _gameState.playerHands[player] ?? [];
    
    for (var card in hand) {
      if (card.canRespondToDraw(chosenColor, attackCardType)) {
        return true;
      }
    }
    return false;
  }

  UnoCard? _getResponseCard(String player, CardColor chosenColor, CardType attackCardType) {
    final hand = _gameState.playerHands[player] ?? [];
    
    for (var card in hand) {
      if (card.type == CardType.wildDraw8 && card.canRespondToDraw(chosenColor, attackCardType)) {
        return card;
      }
    }
    for (var card in hand) {
      if (card.type == CardType.wildDraw4 && card.canRespondToDraw(chosenColor, attackCardType)) {
        return card;
      }
    }
    for (var card in hand) {
      if (card.type == CardType.draw2 && card.canRespondToDraw(chosenColor, attackCardType)) {
        return card;
      }
    }
    return null;
  }

  void _throwDrawTwo(UnoCard card) {
    // Находим следующего игрока ДО смены хода
    final nextIndex = _getNextPlayerIndex(
      _gameState.currentPlayerIndex, 
      _gameState.isClockwise, 
      _gameState.playerCount
    );
    final nextPlayer = _gameState.playerOrder[nextIndex];
    
    _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(2));
    _gameState.drawPileCount = _deck.cards.length;
    
    _gameState.nextTurn();
  }
  
  void _throwWildDraw(UnoCard card) {
    final isDraw8 = card.type == CardType.wildDraw8;
    final baseDraw = isDraw8 ? 8 : 4;
    
    // Находим следующего игрока
    final nextIndex = _getNextPlayerIndex(
      _gameState.currentPlayerIndex, 
      _gameState.isClockwise, 
      _gameState.playerCount
    );
    final nextPlayer = _gameState.playerOrder[nextIndex];
    final nextHand = _gameState.playerHands[nextPlayer] ?? [];
    final chosenColor = _gameState.chosenColor;
    
    if (chosenColor == null) return;
    
    final canRespond = _canRespondToDraw(nextPlayer, chosenColor, card.type);
    final onlyOneCard = canRespond && nextHand.length == 1;
    
    if (onlyOneCard) {
      _gameState.winner = nextPlayer;
      _gameState.playerHands[nextPlayer]!.clear();
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      _gameState.pendingAttackCardType = null;
      return;
    }
    
    _gameState.pendingDrawCount = baseDraw;
    _gameState.pendingAttackCardType = card.type;
    
    if (canRespond && nextHand.length > 1) {
      _gameState.pendingResponsePlayer = nextPlayer;
    } else {
      final drawCount = _gameState.pendingDrawCount ?? 0;
      _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(drawCount));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      _gameState.pendingAttackCardType = null;
      if (_gameState.playerHands[nextPlayer]!.isEmpty) {
        _gameState.winner = nextPlayer;
      }
      _gameState.nextTurn();
    }
  }

  void _respondToPending(UnoCard card) {
    _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
    _gameState.discardPile.add(card);
    
    final isDraw2 = card.type == CardType.draw2;
    final isDraw4 = card.type == CardType.wildDraw4;
    final isDraw8 = card.type == CardType.wildDraw8;
    final attackType = _gameState.pendingAttackCardType;
    
    if (isDraw2) {
      // Находим атакованного игрока (того, кто должен взять карты)
      final attackedPlayerIndex = _getPrevPlayerIndex(
        _gameState.currentPlayerIndex,
        _gameState.isClockwise,
        _gameState.playerCount
      );
      final attackedPlayer = _gameState.playerOrder[attackedPlayerIndex];
      final drawCount = _gameState.pendingDrawCount ?? 0;
      _gameState.playerHands[attackedPlayer]!.addAll(_deck.drawMultiple(drawCount));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      _gameState.pendingAttackCardType = null;
      _gameState.nextTurn();
      _updateTurn();
      _broadcastState();
    } else if (isDraw4 || isDraw8) {
      _pendingResponseCard = card;
      if (widget.playerName.startsWith('Бот')) {
        final newColor = _bot.chooseColor(_gameState.playerHands[widget.playerName]!);
        _onResponseColorChosenForBot(newColor);
      } else {
        _showResponseColorPickerForCard(card);
      }
    }
  }

  void _onResponseColorChosenForBot(CardColor color) {
    if (_pendingResponseCard == null) return;
    
    debugPrint('Бот выбрал цвет: $color для ответа на +4/+8');
    
    final card = _pendingResponseCard!;
    final isDraw8 = card.type == CardType.wildDraw8;
    final baseDraw = isDraw8 ? 8 : 4;
    
    _pendingResponseCard = null;
    
    _gameState.chosenColor = color;
    _gameState.pendingDrawCount = (_gameState.pendingDrawCount ?? 0) + baseDraw;
    _gameState.pendingAttackCardType = card.type;
    
    final nextIndex = _getNextPlayerIndex(
      _gameState.currentPlayerIndex,
      _gameState.isClockwise,
      _gameState.playerCount
    );
    final nextPlayer = _gameState.playerOrder[nextIndex];
    final nextHand = _gameState.playerHands[nextPlayer] ?? [];
    
    final canRespondNext = _canRespondToDraw(nextPlayer, color, card.type);
    
    if (canRespondNext && nextHand.length > 1) {
      _gameState.pendingResponsePlayer = nextPlayer;
    } else {
      final drawCount = _gameState.pendingDrawCount ?? 0;
      _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(drawCount));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      _gameState.pendingAttackCardType = null;
      if (_gameState.playerHands[nextPlayer]!.isEmpty) {
        _gameState.winner = nextPlayer;
      }
      _gameState.nextTurn();
    }
    
    _updateTurn();
    _broadcastState();
  }

  void _showResponseColorPickerForCard(UnoCard card) {
    if (_isResponseColorPickerShowing) return;
    if (_choosingResponseColor) return;
    if (!mounted) return;
    
    if (widget.playerName.startsWith('Бот')) return;
    
    setState(() {
      _choosingResponseColor = true;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _choosingResponseColor && !widget.playerName.startsWith('Бот')) {
        _showResponseColorPicker();
      }
    });
  }

  void _showResponseColorPicker() {
    if (!_choosingResponseColor || _isResponseColorPickerShowing) return;
    if (!mounted) return;
    
    if (widget.playerName.startsWith('Бот')) return;
    
    _isResponseColorPickerShowing = true;
    
    Timer(const Duration(seconds: 10), () {
      if (_isResponseColorPickerShowing && mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        if (mounted) {
          _cancelResponseColorPick();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Время выбора цвета истекло!'), backgroundColor: Colors.red),
          );
        }
      }
    });
    
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async {
          _cancelResponseColorPick();
          return false;
        },
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.color_lens, color: Colors.orange, size: 32),
              SizedBox(width: 12),
              Text('Выберите цвет', style: TextStyle(color: Colors.white, fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Вы ответили на +4/+8!\nВыберите следующий цвет:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildResponseColorOption(CardColor.red, 'Красный', Colors.red, ctx),
                  _buildResponseColorOption(CardColor.blue, 'Синий', Colors.blue, ctx),
                  _buildResponseColorOption(CardColor.green, 'Зелёный', Colors.green, ctx),
                  _buildResponseColorOption(CardColor.yellow, 'Жёлтый', Colors.amber, ctx),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        _isResponseColorPickerShowing = false;
        if (_choosingResponseColor) {
          _cancelResponseColorPick();
        }
      }
    });
  }

  Widget _buildResponseColorOption(CardColor color, String label, Color bgColor, BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        Navigator.of(ctx).pop();
        _onResponseColorChosen(color);
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: bgColor.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _cancelResponseColorPick() {
    if (mounted) {
      setState(() {
        _choosingResponseColor = false;
        _pendingResponseCard = null;
        _isResponseColorPickerShowing = false;
      });
    }
  }

  void _onResponseColorChosen(CardColor color) {
    if (_pendingResponseCard == null) {
      _cancelResponseColorPick();
      return;
    }
    
    debugPrint('Выбран цвет: $color для ответа на +4/+8');
    
    final card = _pendingResponseCard!;
    final isDraw8 = card.type == CardType.wildDraw8;
    final baseDraw = isDraw8 ? 8 : 4;
    
    _choosingResponseColor = false;
    _isResponseColorPickerShowing = false;
    _pendingResponseCard = null;
    
    _gameState.chosenColor = color;
    _gameState.pendingDrawCount = (_gameState.pendingDrawCount ?? 0) + baseDraw;
    _gameState.pendingAttackCardType = card.type;
    
    final nextIndex = _getNextPlayerIndex(
      _gameState.currentPlayerIndex,
      _gameState.isClockwise,
      _gameState.playerCount
    );
    final nextPlayer = _gameState.playerOrder[nextIndex];
    final nextHand = _gameState.playerHands[nextPlayer] ?? [];
    
    final canRespondNext = _canRespondToDraw(nextPlayer, color, card.type);
    
    if (canRespondNext && nextHand.length > 1) {
      _gameState.pendingResponsePlayer = nextPlayer;
    } else {
      final drawCount = _gameState.pendingDrawCount ?? 0;
      _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(drawCount));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      _gameState.pendingAttackCardType = null;
      if (_gameState.playerHands[nextPlayer]!.isEmpty) {
        _gameState.winner = nextPlayer;
      }
      _gameState.nextTurn();
    }
    
    _updateTurn();
    _broadcastState();
  }

  void _applyClearCardEffect(CardColor color) {
    final currentPlayer = _gameState.currentPlayer;
    final hand = _gameState.playerHands[currentPlayer] ?? [];
    final toRemove = hand.where((c) => c.color == color).toList();
    
    if (toRemove.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Нет карт этого цвета для сброса!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    for (var card in toRemove) {
      _gameState.playerHands[currentPlayer]!.removeWhere((c) => c.id == card.id);
      _gameState.discardPile.add(card);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🧹 Вы сбросили ${toRemove.length} ${_colorName(color)} карт вместе с clear!'),
        backgroundColor: _getColorForCard(color),
        duration: const Duration(seconds: 2),
      ));
    }
    
    if (_gameState.playerHands[currentPlayer]!.isEmpty && _gameState.winner == null) {
      _gameState.winner = currentPlayer;
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
    if (_gameState.playerHands[player]!.length == 1 && !_unoPressed && !player.startsWith('Бот')) {
      setState(() {
        _gameState.playerHands[player]!.addAll(_deck.drawMultiple(2));
        _gameState.drawPileCount = _deck.cards.length;
        _needUnoButton = false;
      });
      _showUnoPenaltyMessage(player);
    }
  }

  void _showUnoPenaltyMessage(String player) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(player == widget.playerName ? '⚠️ Вы не нажали УНО! Штраф +2 карты!' : '⚠️ $player не нажал УНО! Штраф +2 карты!'),
      backgroundColor: Colors.red, 
      duration: const Duration(seconds: 3),
    ));
  }

  void _pressUno() {
    if (!_needUnoButton) return;
    
    _unoTimer?.cancel();
    setState(() {
      _unoPressed = true;
      _needUnoButton = false;
    });
    _pulseController.stop();
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ УНО!'), 
      backgroundColor: Colors.green, 
      duration: Duration(seconds: 1),
    ));
  }

  void _applyCardEffect(UnoCard card) {
    switch (card.type) {
      case CardType.skip:
        _gameState.nextTurn();
        break;
      case CardType.reverse:
        if (_gameState.playerCount == 2) {
          // При 2 игроках reverse даёт ещё один ход текущему игроку
          // Не меняем индекс, просто остаёмся
        } else {
          _gameState.isClockwise = !_gameState.isClockwise;
          _gameState.nextTurn();
        }
        break;
      default:
        break;
    }
  }

  void _botMove() {
    if (!mounted || !_isBotTurn || !widget.isHost) return;
    final botName = _gameState.currentPlayer;
    final botHand = _gameState.currentHand(botName);
    final topCard = _gameState.topCard;
    final chosenColor = _gameState.chosenColor;
    
    final botNeedUno = botHand.length == 1;
    bool botUnoPressed = false;
    
    if (botNeedUno) {
      botUnoPressed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🤖 $botName нажал УНО!'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    }

    // Обработка ответа на добор
    if (_gameState.pendingResponsePlayer == botName) {
      if (_gameState.chosenColor != null && _gameState.pendingAttackCardType != null) {
        final canRespond = _canRespondToDraw(botName, _gameState.chosenColor!, _gameState.pendingAttackCardType!);
        if (canRespond) {
          final responseCard = _getResponseCard(botName, _gameState.chosenColor!, _gameState.pendingAttackCardType!);
          if (responseCard != null) {
            final handBefore = _gameState.playerHands[botName]!.length;
            _gameState.playerHands[botName]!.removeWhere((c) => c.id == responseCard.id);
            _gameState.discardPile.add(responseCard);
            
            final handAfter = _gameState.playerHands[botName]!.length;
            
            if (handBefore == 2 && handAfter == 1 && !botUnoPressed) {
              _applyBotUnoPenalty(botName);
            }
            
            final isDraw2 = responseCard.type == CardType.draw2;
            final isDraw4 = responseCard.type == CardType.wildDraw4;
            final isDraw8 = responseCard.type == CardType.wildDraw8;
            
            if (isDraw2) {
              final attackedPlayerIndex = _getPrevPlayerIndex(
                _gameState.currentPlayerIndex,
                _gameState.isClockwise,
                _gameState.playerCount
              );
              final attackedPlayer = _gameState.playerOrder[attackedPlayerIndex];
              final drawCount = _gameState.pendingDrawCount ?? 0;
              _gameState.playerHands[attackedPlayer]!.addAll(_deck.drawMultiple(drawCount));
              _gameState.pendingResponsePlayer = null;
              _gameState.pendingDrawCount = 0;
              _gameState.pendingAttackCardType = null;
              _gameState.nextTurn();
            } else if (isDraw4 || isDraw8) {
              final baseDraw = isDraw8 ? 8 : 4;
              final newColor = _bot.chooseColor(_gameState.playerHands[botName]!);
              _gameState.chosenColor = newColor;
              
              _gameState.pendingDrawCount = (_gameState.pendingDrawCount ?? 0) + baseDraw;
              _gameState.pendingAttackCardType = responseCard.type;
              
              final nextIndex = _getNextPlayerIndex(
                _gameState.currentPlayerIndex,
                _gameState.isClockwise,
                _gameState.playerCount
              );
              final nextPlayer = _gameState.playerOrder[nextIndex];
              final nextHand = _gameState.playerHands[nextPlayer] ?? [];
              
              final canRespondNext = _canRespondToDraw(nextPlayer, newColor, responseCard.type);
              
              if (canRespondNext && nextHand.length > 1) {
                _gameState.pendingResponsePlayer = nextPlayer;
              } else {
                final drawCount = _gameState.pendingDrawCount ?? 0;
                _gameState.playerHands[nextPlayer]!.addAll(_deck.drawMultiple(drawCount));
                _gameState.pendingResponsePlayer = null;
                _gameState.pendingDrawCount = 0;
                _gameState.pendingAttackCardType = null;
              }
              _gameState.nextTurn();
            }
            
            setState(() => _updateTurn());
            _broadcastState();
            return;
          }
        }
      }
      // Не может ответить - берёт карты
      final drawCount = _gameState.pendingDrawCount ?? 0;
      _gameState.playerHands[botName]!.addAll(_deck.drawMultiple(drawCount > 0 ? drawCount : 4));
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      _gameState.pendingAttackCardType = null;
      _gameState.nextTurn();
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    // Обычный ход бота
    final chosenCard = _bot.chooseCard(botHand, topCard, chosenColor);
    if (chosenCard == null) {
      _gameState.playerHands[botName]!.add(_deck.draw());
      _gameState.drawPileCount = _deck.cards.length;
      _gameState.nextTurn();
      setState(() => _updateTurn());
      _broadcastState();
      return;
    }

    final handBefore = _gameState.playerHands[botName]!.length;
    _gameState.playerHands[botName]!.removeWhere((c) => c.id == chosenCard.id);
    _gameState.discardPile.add(chosenCard);
    
    final handAfter = _gameState.playerHands[botName]!.length;
    
    if (handBefore == 2 && handAfter == 1 && !botUnoPressed) {
      _applyBotUnoPenalty(botName);
    }

    if (chosenCard.color == CardColor.wild && chosenCard.type != CardType.wild) {
      _gameState.chosenColor = _bot.chooseColor(_gameState.playerHands[botName]!);
    }

    if (chosenCard.type == CardType.clear) {
      _applyClearCardEffect(chosenCard.color);
      _gameState.nextTurn();
    } else if (chosenCard.type == CardType.draw2) {
      _throwDrawTwo(chosenCard);
      _gameState.nextTurn();
    } else if (chosenCard.type == CardType.wildDraw4 || chosenCard.type == CardType.wildDraw8) {
      if (_gameState.chosenColor == null) {
        _gameState.chosenColor = _bot.chooseColor(_gameState.playerHands[botName]!);
      }
      _throwWildDraw(chosenCard);
      if (_gameState.pendingResponsePlayer == null) _gameState.nextTurn();
    } else {
      _applyCardEffect(chosenCard);
      if (chosenCard.type == CardType.number) {
        _gameState.nextTurn();
      }
    }

    if (_gameState.playerHands[botName]!.isEmpty) _gameState.winner = botName;
    setState(() => _updateTurn());
    _broadcastState();
    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
  }

  void _applyBotUnoPenalty(String player) {
    if (_gameState.playerHands[player]!.length == 1) {
      setState(() {
        _gameState.playerHands[player]!.addAll(_deck.drawMultiple(2));
        _gameState.drawPileCount = _deck.cards.length;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $player не нажал УНО! Штраф +2 карты!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ========== МЕТОДЫ ДЛЯ МУЛЬТИ-СБРОСА ==========

  List<UnoCard> _getSameNumberCards(int number) {
    if (!_isMyTurn) return [];
    final hand = _gameState.currentHand(widget.playerName);
    final topCard = _gameState.topCard;
    
    return hand.where((card) => 
      card.type == CardType.number && 
      card.number == number && 
      card.canPlayOn(topCard, chosenColor: _gameState.chosenColor)
    ).toList();
  }

  List<UnoCard> _getMultiPlayableCards() {
    if (!_isMyTurn) return [];
    final hand = _gameState.currentHand(widget.playerName);
    final topCard = _gameState.topCard;
    
    Map<int, List<UnoCard>> numberGroups = {};
    
    for (var card in hand) {
      if (card.type == CardType.number && card.canPlayOn(topCard, chosenColor: _gameState.chosenColor)) {
        numberGroups.putIfAbsent(card.number!, () => []);
        numberGroups[card.number!]!.add(card);
      }
    }
    
    for (var group in numberGroups.values) {
      if (group.length >= 2) return group;
    }
    return [];
  }

  int? _getSelectedNumber() {
    if (_selectedCardIds.isEmpty) return null;
    final selectedCards = _gameState.currentHand(widget.playerName)
        .where((c) => _selectedCardIds.contains(c.id))
        .toList();
    if (selectedCards.isEmpty) return null;
    return selectedCards.first.number;
  }

  void _confirmMultiPlay() {
    if (_selectedCardIds.isEmpty) return;
    
    final cardsToPlay = _gameState.currentHand(widget.playerName)
        .where((c) => _selectedCardIds.contains(c.id))
        .toList();
    
    if (cardsToPlay.isNotEmpty && cardsToPlay.first.type == CardType.number) {
      final expectedNumber = cardsToPlay.first.number;
      final allSameNumber = cardsToPlay.every((c) => c.type == CardType.number && c.number == expectedNumber);
      
      if (allSameNumber && cardsToPlay.length >= 2) {
        cardsToPlay.sort((a, b) => a.color.index.compareTo(b.color.index));
        
        setState(() {
          _multiSelectMode = false;
          _selectedCardIds.clear();
        });
        _executePlayCard(cardsToPlay);
        return;
      }
    }
    
    setState(() {
      _multiSelectMode = false;
      _selectedCardIds.clear();
    });
  }

  void _onCardTap(UnoCard card) {
    if (!_gameStarted) return;
    
    final isMyPending = _gameState.pendingResponsePlayer == widget.playerName;
    
    bool canRespond = false;
    if (isMyPending && _gameState.chosenColor != null && _gameState.pendingAttackCardType != null) {
      canRespond = card.canRespondToDraw(_gameState.chosenColor, _gameState.pendingAttackCardType!);
    }
    
    if (canRespond) { 
      _respondToPending(card); 
      return; 
    }
    
    if (!_isMyTurn) return;

    bool canPlay = card.canPlayOn(_gameState.topCard, chosenColor: _gameState.chosenColor);
    if (!canPlay) return;
    
    // Двойной тап для быстрого сброса
    if (_lastTappedCardId == card.id && canPlay) {
      _lastTapTimer?.cancel(); 
      _lastTappedCardId = null;
      if (_multiSelectMode) {
        setState(() {
          _multiSelectMode = false;
          _selectedCardIds.clear();
        });
      }
      if (card.color == CardColor.wild && card.type != CardType.wild) {
        _showColorPickerForCard(card);
      } else {
        _executePlayCard([card]);
      }
      return;
    }
    
    _lastTappedCardId = card.id;
    _lastTapTimer?.cancel();
    _lastTapTimer = Timer(const Duration(milliseconds: 350), () { 
      _lastTappedCardId = null; 
    });
    
    // Дикие карты кроме W - выбор цвета
    if (card.color == CardColor.wild && card.type != CardType.wild) {
      _showColorPickerForCard(card);
      return;
    }
    
    // Числовые карты - проверка мульти-сброса
    if (card.type == CardType.number) {
      final sameNumberCards = _getSameNumberCards(card.number!);
      if (sameNumberCards.length >= 2) {
        setState(() {
          _multiSelectMode = true;
          if (_selectedCardIds.contains(card.id)) {
            _selectedCardIds.remove(card.id);
          } else {
            _selectedCardIds.add(card.id);
          }
        });
        return;
      }
    }
    
    if (_multiSelectMode) {
      setState(() {
        _multiSelectMode = false;
        _selectedCardIds.clear();
      });
    }
    _executePlayCard([card]);
  }

  void _showColorPickerForCard(UnoCard card) {
    if (_isColorPickerShowing) return;
    if (_choosingColor) return;
    
    setState(() {
      _choosingColor = true;
      _pendingWildCard = card;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _choosingColor && _pendingWildCard != null) {
        _showColorPicker();
      }
    });
  }

  void _showColorPicker() {
    if (!_choosingColor || _isColorPickerShowing) return;
    if (_pendingWildCard == null) {
      setState(() {
        _choosingColor = false;
        _isColorPickerShowing = false;
      });
      return;
    }
    
    _isColorPickerShowing = true;
    
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async {
          _cancelColorPick();
          return false;
        },
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Row(
            children: [
              Icon(Icons.color_lens, color: Colors.purple, size: 28), 
              SizedBox(width: 12),
              Text('Выберите цвет', style: TextStyle(color: Colors.white, fontSize: 20))
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const Text(
                'Дикая карта — выберите следующий цвет:', 
                style: TextStyle(color: Colors.grey, fontSize: 14)
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                children: [
                  _buildColorOption(CardColor.red, 'Красный', Colors.red, ctx, _onColorChosen),
                  _buildColorOption(CardColor.blue, 'Синий', Colors.blue, ctx, _onColorChosen),
                  _buildColorOption(CardColor.green, 'Зелёный', Colors.green, ctx, _onColorChosen),
                  _buildColorOption(CardColor.yellow, 'Жёлтый', Colors.amber, ctx, _onColorChosen),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted && _choosingColor) {
        _cancelColorPick();
      }
      _isColorPickerShowing = false;
    });
  }

  void _cancelColorPick() {
    if (mounted) {
      setState(() {
        _choosingColor = false;
        _pendingWildCard = null;
      });
    }
  }

  void _onColorChosen(CardColor color) {
    if (_pendingWildCard == null) {
      _cancelColorPick();
      return;
    }
    
    final card = _pendingWildCard!;
    
    setState(() {
      _choosingColor = false;
      _pendingWildCard = null;
    });
    
    _gameState.chosenColor = color;
    _executePlayCard([card]);
  }

  void _executePlayCard(List<UnoCard> cards) async {
    if (cards.isEmpty || _isAnimating) return;
    
    final lastCard = cards.last;
    
    // Проверка: для Wild карт должен быть выбран цвет
    if ((lastCard.type == CardType.wildDraw4 || 
         lastCard.type == CardType.wildDraw8 ||
         lastCard.type == CardType.wild) && 
        _gameState.chosenColor == null) {
      debugPrint('❌ Ошибка: цвет не выбран для Wild карты!');
      return;
    }
    
    _isAnimating = true;
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    final sortedCards = List<UnoCard>.from(cards);
    final handBefore = _gameState.currentHand(widget.playerName).length;
    
    for (var card in sortedCards) {
      _gameState.playerHands[widget.playerName]!.removeWhere((c) => c.id == card.id);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    _gameState.discardPile.add(lastCard);
    
    for (int i = 0; i < sortedCards.length - 1; i++) {
      _gameState.discardPile.add(sortedCards[i]);
    }
    
    final handAfter = _gameState.currentHand(widget.playerName).length;
    
    if (handBefore == cards.length + 1 && handAfter == 1 && !_unoPressed && _gameState.pendingResponsePlayer == null) {
      _needUnoButton = true;
      _pulseController.repeat(reverse: true);
      _startUnoTimer();
    }
    
    if (handAfter == 0) {
      _gameState.winner = widget.playerName;
      _updateTurn();
      _broadcastState();
      if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
      _isAnimating = false;
      return;
    }
    
    if (lastCard.type == CardType.clear) {
      _applyClearCardEffect(lastCard.color);
      _gameState.nextTurn();
    } else if (lastCard.type == CardType.draw2) {
      _throwDrawTwo(lastCard);
      _gameState.nextTurn();
    } else if (lastCard.type == CardType.wildDraw4 || lastCard.type == CardType.wildDraw8) {
      _throwWildDraw(lastCard);
      if (_gameState.pendingResponsePlayer == null) _gameState.nextTurn();
    } else {
      _applyCardEffect(lastCard);
      if (lastCard.type == CardType.number) {
        _gameState.nextTurn();
      }
    }
    
    _updateTurn();
    _broadcastState();
    if (_gameState.winner != null) _showWinDialog(_gameState.winner!);
    _isAnimating = false;
  }

  void _drawCard() async {
    if ((!_isMyTurn && _gameState.pendingResponsePlayer != widget.playerName) || _isAnimating) return;
    if (!_gameStarted) return;
    
    _isAnimating = true;
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (_gameState.pendingResponsePlayer == widget.playerName) {
      final drawCount = _gameState.pendingDrawCount ?? 0;
      for (int i = 0; i < (drawCount > 0 ? drawCount : 4); i++) {
        _gameState.playerHands[widget.playerName]!.add(_deck.draw());
        await Future.delayed(const Duration(milliseconds: 100));
      }
      _gameState.pendingResponsePlayer = null;
      _gameState.pendingDrawCount = 0;
      _gameState.pendingAttackCardType = null;
    } else {
      _gameState.playerHands[widget.playerName]!.add(_deck.draw());
    }
    
    _gameState.drawPileCount = _deck.cards.length;
    _gameState.nextTurn();
    _updateTurn();
    _broadcastState();
    
    _isAnimating = false;
  }

  void _showWinDialog(String winner) {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(children: [
          const Text('🎉', style: TextStyle(fontSize: 32)), 
          const SizedBox(width: 12),
          Text(winner == widget.playerName ? 'Вы победили!' : 'Победа!', 
              style: const TextStyle(color: Colors.white))
        ]),
        content: Text(winner == widget.playerName ? 'Отличная игра! Вы выиграли!' : '$winner выиграл игру!',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () { 
              Navigator.of(ctx).pop();
              widget.server.stop(); 
              Navigator.of(context).pop();
            },
            child: const Text('В меню', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { 
              Navigator.of(ctx).pop();
              if (widget.isHost) { 
                setState(() {
                  _deck = UnoDeck(seed: Random().nextInt(99999)); 
                  _startGameAsHost(); 
                }); 
              } 
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
            child: const Text('Играть снова')),
        ],
      ),
    );
  }

  Widget _buildColorOption(CardColor color, String label, Color bgColor, BuildContext ctx, Function(CardColor) onSelected) {
    return GestureDetector(
      onTap: () {
        Navigator.of(ctx).pop();
        onSelected(color);
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: bgColor.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    if (!_gameStarted) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              CircularProgressIndicator(color: Color(0xFF7C4DFF)), 
              SizedBox(height: 24),
              Text('Ожидание начала игры...', 
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ]
          ),
        ),
      );
    }
    final myHand = _gameState.currentHand(widget.playerName);
    final isPending = _gameState.pendingResponsePlayer == widget.playerName;
    final canDraw = _isMyTurn || isPending;
    final multiCards = _getMultiPlayableCards();

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopPlayers(),
              
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDeck(canDraw),
                          const SizedBox(width: 30),
                          _buildDiscardPile(),
                        ],
                      ),
                      // Кнопка подтверждения мульти-сброса
                      if (_multiSelectMode && _selectedCardIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton.icon(
                            onPressed: _selectedCardIds.length >= 2 ? _confirmMultiPlay : null,
                            icon: const Icon(Icons.send),
                            label: Text('Сбросить ${_selectedCardIds.length} карт (номер ${_getSelectedNumber()})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              if (_needUnoButton) _buildUnoButton(),
              if (isPending && _gameState.pendingDrawCount != null)
                _buildChainInfo(),
              
              _buildBottomPlayers(),
            ],
          ),
          
          _buildChatPanel(),
        ],
      ),
    );
  }
  
  Widget _buildTopPlayers() {
    final topPlayers = widget.players.where((p) => p != widget.playerName).toList();
    
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: topPlayers.length,
        itemBuilder: (context, index) {
          final player = topPlayers[index];
          final isCurrent = player == _gameState.currentPlayer;
          final cardCount = _gameState.playerHands[player]?.length ?? 0;
          final isBot = player.startsWith('Бот');
          
          return Container(
            width: 120,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.green.withOpacity(0.3) : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: isCurrent ? Border.all(color: Colors.greenAccent, width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isBot ? Colors.grey.shade700 : Colors.blue.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBot ? Icons.computer : Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$cardCount 🃏',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                if (player == _gameState.pendingResponsePlayer)
                  const Chip(
                    label: Text('ОТВЕТ!', style: TextStyle(fontSize: 8)),
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.all(0),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildBottomPlayers() {
    final myHand = _gameState.currentHand(widget.playerName);
    final isPending = _gameState.pendingResponsePlayer == widget.playerName;
    
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.playerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (_multiSelectMode && _selectedCardIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Сброс: ${_selectedCardIds.length} карт (номер ${_getSelectedNumber()})',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                if (_gameState.pendingResponsePlayer == widget.playerName)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'ОТВЕТЬТЕ!',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                if (_isMyTurn && _gameState.pendingResponsePlayer != widget.playerName && !_multiSelectMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'ВАШ ХОД',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildPlayerHand(myHand, isPending),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDeck(bool canDraw) {
    return AnimatedDeck(
      canDraw: canDraw,
      cardCount: _gameState.drawPileCount,
      onTap: _drawCard,
      isGlowing: _noPlayableCards && _gameState.pendingResponsePlayer != widget.playerName,
    );
  }
  
  Widget _buildDiscardPile() {
    return AnimatedDiscardPile(card: _gameState.topCard);
  }
  
  Widget _buildChatPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      right: _isChatOpen ? 0 : -320,
      top: 0,
      bottom: 0,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat, color: Color(0xFF7C4DFF), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Чат',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isChatOpen ? Icons.chevron_right : Icons.chevron_left,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _isChatOpen = !_isChatOpen;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  return _buildChatMessage(msg);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Написать...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF7C4DFF)),
                    onPressed: _sendChatMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatMessage(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: msg.isSystem 
            ? Colors.grey.withOpacity(0.2)
            : (msg.playerName == widget.playerName 
                ? const Color(0xFF7C4DFF).withOpacity(0.3)
                : Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isSystem)
            Text(
              msg.playerName,
              style: TextStyle(
                color: msg.playerName == widget.playerName 
                    ? const Color(0xFF7C4DFF)
                    : Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(
            msg.message,
            style: TextStyle(
              color: msg.isSystem ? Colors.grey : Colors.white,
              fontSize: 13,
            ),
          ),
          Text(
            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.grey, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildChainInfo() {
    String responseHint = '';
    final attackType = _gameState.pendingAttackCardType;
    final chosenColor = _gameState.chosenColor;
    
    if (attackType == CardType.draw2) {
      responseHint = 'Ответьте +2, +4, +8 (любые цвета)';
    } else if (attackType == CardType.wildDraw4) {
      responseHint = 'Ответьте +4, +8 (любые цвета) или +2 цвета ${_colorName(chosenColor!)}';
    } else if (attackType == CardType.wildDraw8) {
      responseHint = 'Ответьте +8, +4 (любые цвета) или +2 цвета ${_colorName(chosenColor!)}';
    }
    
    return Container(
      padding: const EdgeInsets.all(8), 
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.3), 
        borderRadius: BorderRadius.circular(12)
      ),
      child: Column(
        children: [
          Text('🔥 На кону ${_gameState.pendingDrawCount ?? 0} карт!', 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(responseHint,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildUnoButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1 + _pulseController.value * 0.05,
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _unoPressed 
                    ? [Colors.green, Colors.greenAccent] 
                    : [Colors.red, Colors.deepOrange],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3 + _pulseController.value * 0.3),
                  blurRadius: 12 + _pulseController.value * 10,
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'У ВАС ОСТАЛАСЬ 1 КАРТА!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20
                        ),
                      ),
                      Text(
                        'Нажмите УНО до конца хода! $_unoSecondsLeft сек',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 1, end: 1.1),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: ElevatedButton(
                        onPressed: _pressUno,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: const Text(
                          'УНО!',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerHand(List<UnoCard> myHand, bool isPending) {
    if (myHand.isEmpty) {
      return const Center(
        child: Text('У вас нет карт!', style: TextStyle(fontSize: 18, color: Colors.white38)),
      );
    }
    
    final totalCards = myHand.length;
    const double cardWidth = 85;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 24 - (_isChatOpen ? 320 : 0);
    
    double cardSpacing;
    
    if (totalCards <= 5) {
      cardSpacing = 10.0;
    } else if (totalCards <= 8) {
      cardSpacing = 25.0;
    } else if (totalCards <= 12) {
      cardSpacing = 20.0;
    } else {
      cardSpacing = 15.0;
    }
    
    final double totalWidth = cardWidth + (totalCards - 1) * cardSpacing;
    if (totalWidth > availableWidth) {
      cardSpacing = (availableWidth - cardWidth) / (totalCards - 1);
      if (cardSpacing < 10) cardSpacing = 10;
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(totalCards, (i) {
          final card = myHand[i];
          final canPlay = _isMyTurn && card.canPlayOn(_gameState.topCard, chosenColor: _gameState.chosenColor);
          
          bool canRespond = false;
          if (isPending && _gameState.chosenColor != null && _gameState.pendingAttackCardType != null) {
            canRespond = card.canRespondToDraw(_gameState.chosenColor, _gameState.pendingAttackCardType!);
          }
          
          final isSelected = _selectedCardIds.contains(card.id);
          final canTap = canPlay || canRespond;
          
          final isMultiSelectable = _multiSelectMode && 
              card.type == CardType.number && 
              card.number == _getSelectedNumber();
          
          return Container(
            key: ValueKey('card_${card.id}'),
            margin: EdgeInsets.only(
              right: i < totalCards - 1 ? cardSpacing : 0,
              top: (canTap || isMultiSelectable) ? 0 : 15,
            ),
            child: AnimatedCard(
              card: card,
              isBig: false,
              isSelected: isSelected,
              canTap: canTap || isMultiSelectable,
              onTap: () => _onCardTap(card),
            ),
          );
        }),
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

class ChatMessage {
  final String playerName;
  final String message;
  final bool isSystem;
  final DateTime timestamp;
  
  ChatMessage({
    required this.playerName,
    required this.message,
    required this.isSystem,
    required this.timestamp,
  });
}