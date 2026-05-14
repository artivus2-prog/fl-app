import 'package:flutter/material.dart';
import 'package:flutter_globe/flutter_globe.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Добро пожаловать!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 250,
              height: 250,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Globe(
                    rotation: _controller.value * 360,
                    earthColor: const Color(0xFF2E7D32),
                    landColor: const Color(0xFF81C784),
                    atmosphereColor: const Color(0xFF64B5F6),
                    atmosphereOpacity: 0.3,
                    starsColor: const Color(0xFF1A237E),
                    starsCount: 200,
                    showAtmosphere: true,
                    showStars: true,
                    showAxis: false,
                    radius: 125,
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Исследуйте мир',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
