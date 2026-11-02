import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BlueprintBackground extends StatelessWidget {
  const BlueprintBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BlueprintPainter(context.colors.grid),
    child: child,
  );
}

class _BlueprintPainter extends CustomPainter {
  const _BlueprintPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .55)
      ..strokeWidth = .6;
    const gap = 32.0;
    for (var x = 0.0; x < size.width; x += gap) {
      for (var y = 0.0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), .75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlueprintPainter oldDelegate) =>
      oldDelegate.color != color;
}
