import 'dart:math' as math;
import 'package:flutter/material.dart';

class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final strokeWidth = w * 0.24;
    final radius = (w - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Arcs
    canvas.drawArc(rect, -math.pi / 2, math.pi / 2, false, paintBlue);
    canvas.drawArc(rect, -math.pi, math.pi / 2, false, paintRed);
    canvas.drawArc(rect, math.pi / 2, math.pi / 2, false, paintYellow);
    canvas.drawArc(rect, 0, math.pi / 2, false, paintGreen);

    // Horizontal blue bar on the right
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
          center.dx, center.dy - strokeWidth / 2, radius + strokeWidth / 2, strokeWidth),
      barPaint,
    );

    // Inner white cutout to form the hollow 'G'
    final innerRadius = radius - strokeWidth / 2;
    canvas.drawCircle(center, innerRadius * 0.65, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
