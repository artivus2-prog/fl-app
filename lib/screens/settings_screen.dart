import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  static String selectedBackground = 'default';
  
  static Color get backgroundColor {
    switch (selectedBackground) {
      case 'green': return const Color(0xFF1B5E20);
      case 'blue': return const Color(0xFF0D1B2A);
      case 'red': return const Color(0xFF3E1010);
      case 'purple': return const Color(0xFF1A0033);
      case 'grey': return const Color(0xFF1A1A1A);
      case 'forest': return const Color(0xFF0D2818);
      case 'night': return const Color(0xFF0A0E27);
      default: return const Color(0xFF0A0A1A);
    }
  }

  final List<Map<String, dynamic>> _backgrounds = [
    {'name': 'Тёмный (по умолчанию)', 'value': 'default', 'color': const Color(0xFF0A0A1A)},
    {'name': 'Зелёное сукно', 'value': 'green', 'color': const Color(0xFF1B5E20)},
    {'name': 'Синий стол', 'value': 'blue', 'color': const Color(0xFF0D1B2A)},
    {'name': 'Бордовый', 'value': 'red', 'color': const Color(0xFF3E1010)},
    {'name': 'Фиолетовый', 'value': 'purple', 'color': const Color(0xFF1A0033)},
    {'name': 'Серый', 'value': 'grey', 'color': const Color(0xFF1A1A1A)},
    {'name': 'Тёмно-зелёный лес', 'value': 'forest', 'color': const Color(0xFF0D2818)},
    {'name': 'Ночное небо', 'value': 'night', 'color': const Color(0xFF0A0E27)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D001A),
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Фон игры', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          ..._backgrounds.map((bg) => Card(
            color: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: bg['color'] as Color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
              ),
              title: Text(bg['name'] as String, style: const TextStyle(color: Colors.white)),
              trailing: selectedBackground == bg['value']
                  ? const Icon(Icons.check_circle, color: Color(0xFF00E676))
                  : const Icon(Icons.circle_outlined, color: Colors.white24),
              onTap: () {
                setState(() => selectedBackground = bg['value'] as String);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Фон изменён! Применится в следующей игре'), duration: Duration(seconds: 2)),
                );
              },
            ),
          )),
        ],
      ),
    );
  }
}
