import 'package:flutter/material.dart';
import 'lobby_screen.dart';
import 'game_screen.dart';
import '../services/game_server.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
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
                // Логотип с анимацией
                ScaleTransition(
                  scale: _logoAnimation,
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
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(2, 2),
                            ),
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
                    onPressed: () => _showBotCountDialog(context),
                    icon: const Icon(Icons.computer, size: 24),
                    label: const Text('Играть с ботами'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                      child: Text(
                        'ИЛИ',
                        style: TextStyle(
                          color: Colors.grey[500],
                          letterSpacing: 2,
                        ),
                      ),
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
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                    onPressed: () => _showJoinDialog(context),
                    icon: const Icon(Icons.wifi, size: 24),
                    label: const Text('Подключиться к игре'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      foregroundColor: const Color(0xFF448AFF),
                      side: const BorderSide(
                        color: Color(0xFF448AFF),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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

  void _showBotCountDialog(BuildContext context) {
    int botCount = 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Row(
            children: [
              Icon(Icons.computer, color: Color(0xFF7C4DFF), size: 28),
              SizedBox(width: 12),
              Text(
                'Игра с ботами',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Выберите количество ботов-соперников',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('1',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                  Expanded(
                    child: Slider(
                      value: botCount.toDouble(),
                      min: 1,
                      max: 4,
                      divisions: 3,
                      activeColor: const Color(0xFF7C4DFF),
                      inactiveColor: Colors.white12,
                      label: '$botCount',
                      onChanged: (value) {
                        setDialogState(() {
                          botCount = value.round();
                        });
                      },
                    ),
                  ),
                  const Text('4',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person,
                        color: Color(0xFF7C4DFF), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Вы + $botCount бот${_botEnding(botCount)} = ${botCount + 1} игрок${_playerEnding(botCount + 1)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  botCount,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.computer,
                      color: Colors.primaries[i % Colors.primaries.length],
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Отмена', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _startBotGame(context, botCount);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Начать игру'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _botEnding(int count) {
    if (count == 1) return '';
    if (count < 5) return 'а';
    return 'ов';
  }

  String _playerEnding(int count) {
    if (count == 1) return '';
    if (count < 5) return 'а';
    return 'ов';
  }

  void _startBotGame(BuildContext context, int botCount) {
    final server = GameServer();
    final players = <String>['Вы'];
    for (int i = 1; i <= botCount; i++) {
      players.add('Бот $i');
    }

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
  }

  // В home_screen.dart замените метод _showJoinDialog на этот:

void _showJoinDialog(BuildContext context) {
  final roomIdController = TextEditingController();
  final playerNameController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Row(
        children: [
          Icon(Icons.wifi, color: Color(0xFF448AFF)),
          SizedBox(width: 12),
          Text('Подключиться к игре', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Введите ID комнаты и ваше имя', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: roomIdController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ID комнаты (например: a1b2c3d4)',
              hintStyle: const TextStyle(color: Colors.grey),
              labelText: 'ID комнаты',
              labelStyle: const TextStyle(color: Color(0xFF448AFF)),
              prefixIcon: const Icon(Icons.meeting_room, color: Color(0xFF448AFF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF448AFF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF448AFF), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: playerNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ваше имя',
              hintStyle: const TextStyle(color: Colors.grey),
              labelText: 'Имя игрока',
              labelStyle: const TextStyle(color: Color(0xFF448AFF)),
              prefixIcon: const Icon(Icons.person, color: Color(0xFF448AFF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF448AFF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF448AFF), width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            final roomId = roomIdController.text.trim().toLowerCase();
            final playerName = playerNameController.text.trim();
            if (roomId.isNotEmpty && playerName.isNotEmpty) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LobbyScreen(
                    isHost: false, 
                    roomId: roomId,
                  ),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF448AFF)),
          child: const Text('Подключиться'),
        ),
      ],
    ),
  );
}
}
