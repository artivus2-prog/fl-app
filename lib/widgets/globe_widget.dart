import 'dart:math';
import 'package:flutter/material.dart';

class GlobeWidget extends StatefulWidget {
  final double size;
  
  const GlobeWidget({super.key, this.size = 250});

  @override
  State<GlobeWidget> createState() => _GlobeWidgetState();
}

class _GlobeWidgetState extends State<GlobeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: GlobePainter(
            rotation: _controller.value * 2 * pi,
          ),
        );
      },
    );
  }
}

class GlobePainter extends CustomPainter {
  final double rotation;

  GlobePainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Фон — космос
    final bgPaint = Paint()..color = const Color(0xFF0D1B2A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Звёзды
    final starPaint = Paint()..color = Colors.white;
    final random = Random(42);
    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // Глобус
    final globePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, globePaint);

    // Континенты (упрощённые овалы)
    final landPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Северная Америка
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-20, -40), width: 60, height: 80),
      landPaint,
    );

    // Южная Америка
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-10, 30), width: 35, height: 50),
      landPaint,
    );

    // Европа
    canvas.drawOval(
      Rect.fromCenter(center: Offset(30, -30), width: 50, height: 40),
      landPaint,
    );

    // Африка
    canvas.drawOval(
      Rect.fromCenter(center: Offset(25, 20), width: 45, height: 65),
      landPaint,
    );

    // Азия
    canvas.drawOval(
      Rect.fromCenter(center: Offset(70, -20), width: 70, height: 55),
      landPaint,
    );

    // Австралия
    canvas.drawOval(
      Rect.fromCenter(center: Offset(80, 50), width: 25, height: 20),
      landPaint,
    );

    canvas.restore();

    // Атмосфера
    final atmospherePaint = Paint()
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius + 2, atmospherePaint);

    // Блик
    final gradient = RadialGradient(
      center: const Alignment(-0.4, -0.4),
      radius: 0.6,
      colors: [
        Colors.white.withValues(alpha: 0.3),
        Colors.transparent,
      ],
    );
    final rect = Rect.fromCircle(center: center, radius: radius);
    final shadowPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawCircle(center, radius, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant GlobePainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
