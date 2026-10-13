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
    this.animationDuration = const Duration(milliseconds: 350),
    this.isDotted = false,
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

  /// Duration of the color transition.
  final Duration animationDuration;

  final bool isDotted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final inactiveColor =
        offColor ?? theme.colorScheme.outline.withValues(alpha: 0.1);

    return ListenableBuilder(
      listenable: Runtime.singleton,
      builder: (context, _) {
        final active = isOn();

        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: active ? onColor : inactiveColor),
          duration: animationDuration,
          curve: Curves.easeInOut,
          builder: (context, animatedColor, child) {
            return CustomPaint(
              painter: _ConnectionPainter(
                points: points,
                color: animatedColor ?? inactiveColor,
                strokeWidth: strokeWidth,
                isDotted: isDotted,
              ),
              child: const SizedBox.expand(),
            );
          },
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
    this.isDotted = false,
  });

  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double cornerRadius;
  final bool isDotted;

  void _drawDottedPath(Canvas canvas, Path path, Paint paint) {
    const dotSpacing = 8.0;
    const dotRadius = 1.5;

    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      for (
        double distance = 0;
        distance < metric.length;
        distance += dotSpacing
      ) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) continue;

        canvas.drawCircle(
          tangent.position,
          dotRadius,
          Paint()
            ..color = paint.color
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

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

    if (isDotted) {
      _drawDottedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

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

    const arrowLength = 16.0; // Larger arrowhead
    const arrowAngle = 0.48; // Slightly narrower, cleaner shape

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
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.isDotted != isDotted;
  }
}
