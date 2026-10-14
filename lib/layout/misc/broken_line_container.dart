import 'dart:math' as math;
import 'package:flutter/material.dart';

class BrokenLineContainer extends StatelessWidget {
  const BrokenLineContainer({
    super.key,
    required this.title,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.strokeWidth = 1.5,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  final String title;
  final double width;
  final double height;
  final double borderRadius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BrokenBorderPainter(
          color: theme.colorScheme.outline,
          strokeWidth: strokeWidth,
          radius: borderRadius,
          dashLength: dashLength,
          gapLength: gapLength,
          title: title,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: const Offset(0, -10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: theme.scaffoldBackgroundColor,
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrokenBorderPainter extends CustomPainter {
  const _BrokenBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
    required this.title,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;
  final String title;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    // Draw the dashed border, leaving a gap behind the centered title.
    final titleWidth = title.isEmpty ? 0.0 : 0.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BrokenBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}
