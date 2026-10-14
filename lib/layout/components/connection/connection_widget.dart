import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/connection.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'dart:math' as math;
// Import the file containing your Connection class.

class ConnectionWidget extends StatefulWidget {
  const ConnectionWidget({
    super.key,
    required this.points,
    required this.connection,
    required this.onColor,
    this.offColor,
    this.strokeWidth = 3,
    this.animationDuration = const Duration(milliseconds: 350),
    this.isDotted = false,
  });

  /// Coordinates relative to the components area's top-left corner.
  final List<Offset> points;

  /// Returns the Connection controlled by Runtime.
  final Connection Function() connection;

  final Color onColor;
  final Color? offColor;
  final double strokeWidth;
  final Duration animationDuration;
  final bool isDotted;

  @override
  State<ConnectionWidget> createState() => _ConnectionWidgetState();
}

class _ConnectionWidgetState extends State<ConnectionWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 2.5,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 2.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
    ]).animate(_scaleController);
  }

  void _handleRuntimeChange() {
    final connection = widget.connection();

    final currentMicroStep = Runtime.singleton.microStepNumber;

    final isCurrentConnection =
        connection.active && (connection.microStepNumber == currentMicroStep);

    // Trigger once when this connection becomes the current microstep's
    // active connection. Ignore subsequent notifications for the same match.
    if (isCurrentConnection) {
      _scaleController.repeat();
    } else {
      _scaleController.stop();
      _scaleController.reset();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final inactiveColor =
        widget.offColor ?? theme.colorScheme.outline.withValues(alpha: 0.1);

    return ListenableBuilder(
      listenable: Runtime.singleton,
      builder: (context, _) {
        final connection = widget.connection();
        _handleRuntimeChange();

        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            end: connection.active ? widget.onColor : inactiveColor,
          ),
          duration: widget.animationDuration,
          curve: Curves.easeInOut,
          builder: (context, animatedColor, child) {
            return AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConnectionPainter(
                    points: widget.points,
                    color: animatedColor ?? inactiveColor,
                    strokeWidth: widget.strokeWidth * _animation.value,
                    isDotted: widget.isDotted,
                  ),
                  child: const SizedBox.expand(),
                );
              },
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

  void _drawDottedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double strokeWidth,
  ) {
    const dotSpacing = 8.0;
    final dotRadius = 1.5 * strokeWidth / 3;

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
      _drawDottedPath(canvas, path, paint, strokeWidth);
    } else {
      canvas.drawPath(path, paint);
    }

    _drawArrowhead(canvas, paint, strokeWidth);
  }

  void _drawArrowhead(Canvas canvas, Paint linePaint, double strokeWidth) {
    final base = points.last;

    // Find the last non-zero-length segment.
    Offset? previous;
    for (int i = points.length - 2; i >= 0; i--) {
      if ((base - points[i]).distance > 0) {
        previous = points[i];
        break;
      }
    }

    if (previous == null) return;

    final angle = (base - previous).direction;

    final arrowLength = 20.0 * strokeWidth / 10;
    const arrowAngle = 0.9;

    // Tip extends forward from the last point.
    final tip = Offset(
      base.dx + arrowLength * math.cos(angle),
      base.dy + arrowLength * math.sin(angle),
    );

    // Base corners sit at the last point's position.
    final left = Offset(
      base.dx -
          arrowLength * math.cos(arrowAngle) * math.cos(angle) +
          arrowLength * math.sin(arrowAngle) * math.sin(angle),
      base.dy -
          arrowLength * math.cos(arrowAngle) * math.sin(angle) -
          arrowLength * math.sin(arrowAngle) * math.cos(angle),
    );

    final right = Offset(
      base.dx -
          arrowLength * math.cos(arrowAngle) * math.cos(angle) -
          arrowLength * math.sin(arrowAngle) * math.sin(angle),
      base.dy -
          arrowLength * math.cos(arrowAngle) * math.sin(angle) +
          arrowLength * math.sin(arrowAngle) * math.cos(angle),
    );

    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
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
