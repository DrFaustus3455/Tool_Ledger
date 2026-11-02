import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false, this.lightOnDark = false});
  final bool compact;
  final bool lightOnDark;
  @override
  Widget build(BuildContext context) {
    final foreground = lightOnDark
        ? AppColors.dark.textPrimary
        : context.colors.textPrimary;
    final mark = SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(painter: _MarkPainter(context.colors.accent)),
    );
    if (compact) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 11),
        Flexible(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOOL',
                  style: TextStyle(
                    fontFamily: AppTheme.headingFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    letterSpacing: 1.2,
                    color: foreground,
                  ),
                ),
                Text(
                  'LEDGER',
                  style: TextStyle(
                    fontFamily: AppTheme.headingFont,
                    fontWeight: FontWeight.w400,
                    fontSize: 20,
                    letterSpacing: 1.2,
                    color: context.colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const s = 10.0;
    canvas.drawLine(const Offset(1, 1), const Offset(s, 1), p);
    canvas.drawLine(const Offset(1, 1), const Offset(1, s), p);
    canvas.drawLine(Offset(size.width - 1, 1), Offset(size.width - s, 1), p);
    canvas.drawLine(Offset(size.width - 1, 1), Offset(size.width - 1, s), p);
    canvas.drawLine(Offset(1, size.height - 1), Offset(s, size.height - 1), p);
    canvas.drawLine(Offset(1, size.height - 1), Offset(1, size.height - s), p);
    canvas.drawLine(
      Offset(size.width - 1, size.height - 1),
      Offset(size.width - s, size.height - 1),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 1, size.height - 1),
      Offset(size.width - 1, size.height - s),
      p,
    );
    canvas.drawRect(Rect.fromLTWH(11, 9, 14, 18), p);
    canvas.drawLine(const Offset(14, 14), const Offset(22, 14), p);
    canvas.drawLine(const Offset(14, 19), const Offset(22, 19), p);
    canvas.drawLine(const Offset(14, 24), const Offset(19, 24), p);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
