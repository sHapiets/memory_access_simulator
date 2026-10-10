import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';

class DiskWidget extends StatelessWidget {
  const DiskWidget({super.key});

  static const double width = 150;
  static const double height = 150;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final runtime = Runtime.singleton;

    return FittedBox(
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.album_rounded, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Disk',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Disk graphic
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ListenableBuilder(
                    listenable: runtime,
                    builder: (context, _) {
                      final bool isDiskAccessed = (runtime.connectMMUtoDisk);

                      return CustomPaint(
                        painter: _DiskPainter(
                          diskColor: isDiskAccessed
                              ? colors.primary
                              : colors.outline,
                          outlineColor: isDiskAccessed
                              ? colors.primary
                              : colors.outline,
                          holeColor: colors.surface,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiskPainter extends CustomPainter {
  const _DiskPainter({
    required this.diskColor,
    required this.outlineColor,
    required this.holeColor,
  });

  final Color diskColor;
  final Color outlineColor;
  final Color holeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.43;
    final holeRadius = radius * 0.22;

    // Main disk surface
    final diskPaint = Paint()
      ..color = diskColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, diskPaint);

    // Outer rim
    final rimPaint = Paint()
      ..color = diskColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, rimPaint);

    // Center hole
    canvas.drawCircle(
      center,
      holeRadius,
      Paint()
        ..color = holeColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      holeRadius,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _DiskPainter oldDelegate) {
    return diskColor != oldDelegate.diskColor ||
        outlineColor != oldDelegate.outlineColor ||
        holeColor != oldDelegate.holeColor;
  }
}
