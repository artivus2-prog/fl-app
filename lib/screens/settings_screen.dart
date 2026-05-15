import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  static String selectedBackground = 'default';
  static String? customImagePath;
  static Uint8List? customImageBytes;
  
  static Color get backgroundColor {
    if (selectedBackground == 'custom' && customImageBytes != null) {
      return Colors.black;
    }
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
  
  static BackgroundType get backgroundType {
    if (selectedBackground == 'custom' && customImageBytes != null) {
      return BackgroundType.image;
    }
    return BackgroundType.color;
  }
  
  static Uint8List? get backgroundImage => customImageBytes;

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

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedImage();
  }

  Future<void> _loadSavedImage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/background_image.png');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          customImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки изображения: $e');
    }
  }

  Future<void> _saveImage(Uint8List bytes) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/background_image.png');
      await file.writeAsBytes(bytes);
      setState(() {
        customImageBytes = bytes;
      });
    } catch (e) {
      debugPrint('Ошибка сохранения изображения: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isLoading = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _saveImage(bytes);
        setState(() {
          selectedBackground = 'custom';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Фоновое изображение установлено!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeCustomImage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/background_image.png');
      if (await file.exists()) {
        await file.delete();
      }
      setState(() {
        customImageBytes = null;
        selectedBackground = 'default';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Фоновое изображение удалено'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка удаления: $e');
    }
  }

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
          // Секция с пользовательским фоном
          Card(
            color: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.photo_library, color: Color(0xFF7C4DFF), size: 28),
                      SizedBox(width: 12),
                      Text(
                        'СВОЙ ФОН',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (customImageBytes != null) ...[
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
                            image: DecorationImage(
                              image: MemoryImage(customImageBytes!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.change_circle),
                                label: const Text('Сменить фото'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C4DFF),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _removeCustomImage,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Удалить'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Выбрать из галереи'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C4DFF),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Сделать фото'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF7C4DFF)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Секция с цветами фона
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
            color: selectedBackground == bg['value'] && customImageBytes == null
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
                    color: selectedBackground == bg['value'] && customImageBytes == null
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
              trailing: selectedBackground == bg['value'] && customImageBytes == null
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
                      'Вы можете установить любое изображение в качестве фона. '
                      'Поддерживаются форматы JPG, PNG. '
                      'Изображение будет автоматически подогнано под размер экрана.',
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

enum BackgroundType { color, image }