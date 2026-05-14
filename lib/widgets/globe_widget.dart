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
      duration: const Duration(seconds: 15),
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
          painter: GlobePainter(rotation: _controller.value * 2 * pi),
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

    // Тёмный космический фон
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0E27),
    );

    // Звёзды
    final starPaint = Paint()..color = Colors.white;
    final random = Random(42);
    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.8 + 0.2;
      starPaint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), random.nextDouble() * 2, starPaint);
    }

    // Рисуем глобус
    canvas.save();
    
    // Обрезаем по кругу
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    // Океан
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.7,
          colors: [
            const Color(0xFF1E88E5),
            const Color(0xFF1565C0),
            const Color(0xFF0D47A1),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.translate(center.dx, center.dy);
    
    // Меридианы и параллели
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Параллели
    for (int i = 1; i < 18; i++) {
      final y = -radius + (radius * 2 * i / 18);
      final r = sqrt(radius * radius - y * y);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, y), width: r * 2, height: 4),
        gridPaint,
      );
    }

    // Меридианы (вращаются)
    for (int i = 0; i < 12; i++) {
      final angle = (i * pi / 6) + rotation;
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      
      final path = Path();
      for (double y = -radius; y <= radius; y += 2) {
        final x = sqrt(radius * radius - y * y) * sin(angle);
        final z = sqrt(radius * radius - y * y) * cos(angle);
        if (z > 0) {
          if (path.getCurrentPoint() == null) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
      }
      canvas.drawPath(path, paint);
    }

    // Континенты
    drawContinents(canvas, radius, rotation);

    canvas.restore();

    // Атмосфера (свечение)
    final atmospherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [
          const Color(0xFF64B5F6).withOpacity(0.4),
          const Color(0xFF64B5F6).withOpacity(0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 15));
    
    canvas.drawCircle(center, radius + 15, atmospherePaint);

    // Контур глобуса
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF64B5F6).withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void drawContinents(Canvas canvas, double radius, double rotation) {
    final landPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;

    // Список континентов: x, y, ширина, высота
    final continents = [
      // Северная Америка
      [-30.0, -50.0, 50.0, 70.0],
      [-50.0, -30.0, 30.0, 40.0],
      // Южная Америка
      [-20.0, 20.0, 25.0, 45.0],
      // Европа
      [20.0, -45.0, 35.0, 30.0],
      [40.0, -35.0, 25.0, 25.0],
      // Африка
      [15.0, 10.0, 30.0, 55.0],
      [30.0, 0.0, 20.0, 20.0],
      // Азия
      [55.0, -35.0, 55.0, 50.0],
      [70.0, -15.0, 30.0, 35.0],
      [85.0, 0.0, 15.0, 20.0],
      // Австралия
      [70.0, 50.0, 20.0, 15.0],
      // Антарктида
      [0.0, 75.0, 60.0, 15.0],
      // Гренландия
      [-40.0, -70.0, 15.0, 12.0],
    ];

    // Масштабируем под радиус
    final scale = radius / 100;

    for (final c in continents) {
      final x = c[0] * scale;
      final y = c[1] * scale;
      final w = c[2] * scale;
      final h = c[3] * scale;
      
      // Рисуем только если континент на видимой стороне
      // Упрощённо: рисуем все, но с поворотом
      final rotated = rotatePoint(x, y, rotation);
      
      // Небольшое смещение для объёма
      final dx = sin(rotation) * 5;
      
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rotated[0] + dx, rotated[1]),
          width: w,
          height: h,
        ),
        landPaint,
      );
    }

    // Более тёмные пятна для рельефа
    final darkLand = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.fill;

    final details = [
      [-25.0, -45.0, 15.0, 20.0],
      [20.0, 15.0, 10.0, 15.0],
      [60.0, -25.0, 15.0, 10.0],
    ];

    for (final d in details) {
      final x = d[0] * scale;
      final y = d[1] * scale;
      final rotated = rotatePoint(x, y, rotation);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rotated[0], rotated[1]),
          width: d[2] * scale,
          height: d[3] * scale,
        ),
        darkLand,
      );
    }
  }

  List<double> rotatePoint(double x, double y, double angle) {
    final cosA = cos(angle);
    final sinA = sin(angle);
    return [
      x * cosA - y * sinA,
      x * sinA + y * cosA,
    ];
  }

  @override
  bool shouldRepaint(covariant GlobePainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
