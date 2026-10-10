import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'dart:math' as math;

class ConnectionWidget extends StatelessWidget {
  const ConnectionWidget({
    super.key,
    required this.points,
    required this.isOn,
    required this.onColor,
    this.offColor,
    this.strokeWidth = 3,
  });

  /// Coordinates relative to the components area's top-left corner.
  /// First point is the start, last point is the end.
  final List<Offset> points;

  /// Reads the current connection state from Runtime.
  final bool Function() isOn;

  /// Color used when the connection is active.
  final Color onColor;

  /// Optional inactive color. Defaults to a muted theme outline.
  final Color? offColor;

  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Runtime.singleton,
      builder: (context, _) {
        final active = isOn();

        return CustomPaint(
          painter: _ConnectionPainter(
            points: points,
            color: active
                ? onColor
                : offColor ?? theme.colorScheme.outline.withValues(alpha: 0.1),
            strokeWidth: strokeWidth,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.cornerRadius = 12,
  });

  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    // Round each bend while preserving the start and end points.
    for (int i = 1; i < points.length - 1; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final next = points[i + 1];

      final incomingLength = (current - previous).distance;
      final outgoingLength = (next - current).distance;

      if (incomingLength == 0 || outgoingLength == 0) {
        path.lineTo(current.dx, current.dy);
        continue;
      }

      final radius = math.min(
        cornerRadius,
        math.min(incomingLength / 2, outgoingLength / 2),
      );

      final beforeCorner = Offset(
        current.dx + (previous.dx - current.dx) * radius / incomingLength,
        current.dy + (previous.dy - current.dy) * radius / incomingLength,
      );

      final afterCorner = Offset(
        current.dx + (next.dx - current.dx) * radius / outgoingLength,
        current.dy + (next.dy - current.dy) * radius / outgoingLength,
      );

      path
        ..lineTo(beforeCorner.dx, beforeCorner.dy)
        ..quadraticBezierTo(
          current.dx,
          current.dy,
          afterCorner.dx,
          afterCorner.dy,
        );
    }

    path.lineTo(points.last.dx, points.last.dy);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);

    _drawArrowhead(canvas, paint);
  }

  void _drawArrowhead(Canvas canvas, Paint linePaint) {
    final end = points.last;

    // Find the last non-zero-length segment.
    Offset? previous;
    for (int i = points.length - 2; i >= 0; i--) {
      if ((end - points[i]).distance > 0) {
        previous = points[i];
        break;
      }
    }

    if (previous == null) return;

    final angle = (end - previous).direction;
    const arrowLength = 11.0;
    const arrowAngle = 0.55;

    final left = Offset(
      end.dx - arrowLength * math.cos(angle - arrowAngle),
      end.dy - arrowLength * math.sin(angle - arrowAngle),
    );

    final right = Offset(
      end.dx - arrowLength * math.cos(angle + arrowAngle),
      end.dy - arrowLength * math.sin(angle + arrowAngle),
    );

    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = linePaint.color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
