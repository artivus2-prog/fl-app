import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedBackground = 'default';
  
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
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: загрузить из SharedPreferences
    setState(() {});
  }

  Future<void> _saveSettings(String value) async {
    // TODO: сохранить в SharedPreferences
    setState(() => _selectedBackground = value);
  }

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
              trailing: _selectedBackground == bg['value']
                  ? const Icon(Icons.check_circle, color: Color(0xFF00E676))
                  : const Icon(Icons.circle_outlined, color: Colors.white24),
              onTap: () => _saveSettings(bg['value'] as String),
            ),
          )),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Своё изображение', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.add_photo_alternate, color: Color(0xFF7C4DFF), size: 40),
              title: const Text('Выбрать из галереи', style: TextStyle(color: Colors.white)),
              subtitle: const Text('PNG, JPG до 5 МБ', style: TextStyle(color: Colors.grey)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Выбор изображения будет доступен в следующем обновлении')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
