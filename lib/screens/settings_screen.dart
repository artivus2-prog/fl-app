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
    {'name': 'Тёмный (по умолчанию)', 'value': 'default', 'color': const Color(0xFF0A0A1A), 'icon': Icons.dark_mode},
    {'name': 'Зелёное сукно', 'value': 'green', 'color': const Color(0xFF1B5E20), 'icon': Icons.grass},
    {'name': 'Синий стол', 'value': 'blue', 'color': const Color(0xFF0D1B2A), 'icon': Icons.water},
    {'name': 'Бордовый', 'value': 'red', 'color': const Color(0xFF3E1010), 'icon': Icons.color_lens},
    {'name': 'Фиолетовый', 'value': 'purple', 'color': const Color(0xFF1A0033), 'icon': Icons.color_lens},
    {'name': 'Серый', 'value': 'grey', 'color': const Color(0xFF1A1A1A), 'icon': Icons.color_lens},
    {'name': 'Тёмно-зелёный лес', 'value': 'forest', 'color': const Color(0xFF0D2818), 'icon': Icons.forest},
    {'name': 'Ночное небо', 'value': 'night', 'color': const Color(0xFF0A0E27), 'icon': Icons.nightlight_round},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D001A),
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(Icons.palette, color: Color(0xFF00E676), size: 24),
                SizedBox(width: 12),
                Text(
                  'ЦВЕТА ФОНА',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._backgrounds.map((bg) => Card(
            color: selectedBackground == bg['value']
                ? const Color(0xFF7C4DFF).withOpacity(0.2)
                : const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bg['color'] as Color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectedBackground == bg['value']
                        ? const Color(0xFF7C4DFF)
                        : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Icon(
                  bg['icon'] as IconData,
                  color: Colors.white.withOpacity(0.7),
                  size: 24,
                ),
              ),
              title: Text(
                bg['name'] as String,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: selectedBackground == bg['value']
                  ? const Icon(Icons.check_circle, color: Color(0xFF00E676))
                  : const Icon(Icons.circle_outlined, color: Colors.white24),
              onTap: () {
                setState(() {
                  selectedBackground = bg['value'] as String;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Цвет фона изменён!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          )),
          
          const SizedBox(height: 16),
          
          // Информация
          Card(
            color: const Color(0xFF1A1A2E).withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Выберите цвет фона для игры.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}