import 'package:flutter/material.dart';
import 'package:memory_access_simulator/layout/components/access_sequence_widget.dart';
import 'package:memory_access_simulator/layout/components/components_area.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // ================================================================
  // Configurable pane width limits (logical pixels)
  // ================================================================

  static const double minLeftWidth = 180;
  static const double maxLeftWidth = 420;

  static const double minMiddleWidth = 420;
  static const double maxMiddleWidth = 1400;

  static const double minRightWidth = 220;
  static const double maxRightWidth = 600;

  static const double dividerWidth = 12;

  // Null means use the initial proportions.
  double? _leftWidth;
  double? _middleWidth;

  double _clamp(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final availableWidth = totalWidth - dividerWidth * 2;

        // Preserve the original 8 : 25 : 10 proportions initially.
        final initialLeft = availableWidth * 6 / 43;
        final initialMiddle = availableWidth * 30 / 43;

        double left = _leftWidth ?? initialLeft;
        double middle = _middleWidth ?? initialMiddle;
        double right = availableWidth - left - middle;

        // If the viewport is too small to satisfy every minimum,
        // fall back to proportional sizing until enough room is available.
        final minimumTotal = minLeftWidth + minMiddleWidth + minRightWidth;

        if (availableWidth < minimumTotal) {
          left = availableWidth * 8 / 43;
          middle = availableWidth * 25 / 43;
          right = availableWidth - left - middle;
        } else {
          // Keep each pane within its limits, while leaving room
          // for the minimum widths of the other panes.
          left = _clamp(
            left,
            minLeftWidth,
            _min(maxLeftWidth, availableWidth - minMiddleWidth - minRightWidth),
          );

          middle = _clamp(
            middle,
            minMiddleWidth,
            _min(maxMiddleWidth, availableWidth - left - minRightWidth),
          );

          right = availableWidth - left - middle;

          // Respect the right pane's limits too.
          if (right < minRightWidth) {
            final adjustment = minRightWidth - right;
            middle -= adjustment;
            right += adjustment;
          } else if (right > maxRightWidth) {
            final adjustment = right - maxRightWidth;
            middle += adjustment;
            right -= adjustment;
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: left,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: AccessSequenceWidget(),
              ),
            ),

            _buildDivider(
              onDrag: (delta) {
                if (availableWidth < minimumTotal) return;

                final minDelta = _max(
                  minLeftWidth - left,
                  middle - maxMiddleWidth,
                );
                final maxDelta = _min(
                  maxLeftWidth - left,
                  middle - minMiddleWidth,
                );

                final adjustedDelta = _clamp(delta, minDelta, maxDelta);

                setState(() {
                  _leftWidth = left + adjustedDelta;
                  _middleWidth = middle - adjustedDelta;
                });
              },
            ),

            SizedBox(
              width: middle,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: ComponentsArea(),
              ),
            ),

            _buildDivider(
              onDrag: (delta) {
                if (availableWidth < minimumTotal) return;

                final minDelta = _max(
                  minMiddleWidth - middle,
                  right - maxRightWidth,
                );
                final maxDelta = _min(
                  maxMiddleWidth - middle,
                  right - minRightWidth,
                );

                final adjustedDelta = _clamp(delta, minDelta, maxDelta);

                setState(() {
                  _middleWidth = middle + adjustedDelta;
                });
              },
            ),

            SizedBox(
              width: right,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: Text('Log/Statistics')),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDivider({required ValueChanged<double> onDrag}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          onDrag(details.delta.dx);
        },
        child: SizedBox(
          width: dividerWidth,
          child: Center(
            child: Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _min(double a, double b) => a < b ? a : b;

  double _max(double a, double b) => a > b ? a : b;
}
