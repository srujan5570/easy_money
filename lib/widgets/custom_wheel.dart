import 'dart:math';
import 'package:flutter/material.dart';

class CustomWheel extends StatelessWidget {
  final Animation<double> animation;
  final int segments;
  final List<Color> colors;
  final List<int> rewards;

  const CustomWheel({
    super.key,
    required this.animation,
    this.segments = 8,
    List<Color>? colors,
    List<int>? rewards,
  }) : colors = colors ?? const [
          Color(0xFF4CAF50), // Green
          Color(0xFF2196F3), // Blue
          Color(0xFFFFC107), // Amber
          Color(0xFFE91E63), // Pink
          Color(0xFF9C27B0), // Purple
          Color(0xFFFF5722), // Deep Orange
          Color(0xFF00BCD4), // Cyan
          Color(0xFFFF9800), // Orange
        ],
       rewards = rewards ?? const [10, 25, 50, 100, 10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: animation.value,
          child: CustomPaint(
            size: const Size(300, 300),
            painter: WheelPainter(
              segments: segments,
              colors: colors,
              rewards: rewards,
            ),
          ),
        );
      },
    );
  }
}

class WheelPainter extends CustomPainter {
  final int segments;
  final List<Color> colors;
  final List<int> rewards;

  WheelPainter({
    required this.segments,
    required this.colors,
    required this.rewards,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / segments;
    
    // Start from the top (pointing upward)
    final startOffset = -pi / 2;
    
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw outer shadow for 3D effect
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius, shadowPaint);

    // Draw segments with gradient for 3D effect
    for (int i = 0; i < segments; i++) {
      final startAngle = startOffset + (i * segmentAngle);
      final baseColor = colors[i % colors.length];
      
      // Create gradient for 3D effect with more pronounced lighting
      final gradient = RadialGradient(
        center: const Alignment(-0.5, -0.5),
        radius: 1.2,
        colors: [
          Color.lerp(baseColor, Colors.white, 0.4)!,
          baseColor,
          Color.lerp(baseColor, Colors.black, 0.3)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      paint.shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          segmentAngle,
          true,
        )
        ..close();

      canvas.drawPath(path, paint);

      // Draw segment dividers with glow effect
      final dividerPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(startAngle),
          center.dy + radius * sin(startAngle),
        ),
        dividerPaint,
      );

      // Draw reward numbers with enhanced style
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rewards[i]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black45,
                offset: Offset(2, 2),
                blurRadius: 4,
              ),
              Shadow(
                color: Colors.black26,
                offset: Offset(-1, -1),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position text in the middle of each segment
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius = radius * 0.65;
      final textCenter = Offset(
        center.dx + textRadius * cos(textAngle),
        center.dy + textRadius * sin(textAngle),
      );

      canvas.save();
      canvas.translate(textCenter.dx, textCenter.dy);
      canvas.rotate(textAngle + pi / 2);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Draw center circle with enhanced metallic effect
    final centerGradient = SweepGradient(
      colors: const [
        Colors.white,
        Color(0xFFE0E0E0),
        Color(0xFFBDBDBD),
        Colors.white,
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    paint
      ..shader = centerGradient.createShader(
        Rect.fromCircle(center: center, radius: radius * 0.15),
      )
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.15, paint);

    // Draw metallic border with enhanced effect
    final borderGradient = SweepGradient(
      colors: [
        Colors.white.withOpacity(0.9),
        Colors.white.withOpacity(0.3),
        Colors.white.withOpacity(0.9),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    paint
      ..shader = borderGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, paint);

    // Add inner shadow to the border
    paint
      ..shader = null
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 2, paint);
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) => false;
} 