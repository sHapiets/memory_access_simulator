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
  // Configurable pane size limits
  // ================================================================

  static const double minLeftWidth = 160;
  static const double maxLeftWidth = 320;

  static const double minMiddleWidth = 800;
  static const double maxMiddleWidth = 1900;

  static const double minSequenceHeight = 50;
  static const double minLogHeight = 150;

  static const double dividerWidth = 12;
  static const double dividerHeight = 20;

  // Horizontal divider: left pane width.
  double? _leftWidth;

  // Vertical divider: height of the access sequence pane.
  double? _sequenceHeight;

  double _clamp(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
  }

  double _min(double a, double b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final availableWidth = totalWidth - dividerWidth;

        final initialLeft = availableWidth * 0.30;

        double left = _leftWidth ?? initialLeft;
        double middle = availableWidth - left;

        if (availableWidth < minLeftWidth + minMiddleWidth) {
          left = availableWidth * 0.32;
          middle = availableWidth - left;
        } else {
          left = _clamp(
            left,
            minLeftWidth,
            _min(maxLeftWidth, availableWidth - minMiddleWidth),
          );

          middle = availableWidth - left;

          if (middle > maxMiddleWidth) {
            middle = maxMiddleWidth;
            left = availableWidth - middle;
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ========================================================
            // LEFT COLUMN: Access Sequence + Log / Statistics
            // ========================================================
            SizedBox(
              width: left,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: LayoutBuilder(
                  builder: (context, leftConstraints) {
                    final totalHeight = leftConstraints.maxHeight;
                    final availableHeight = totalHeight - dividerHeight;

                    // Default: 60% sequence, 40% log/statistics.
                    final initialSequenceHeight = availableHeight * 0.42;

                    double sequenceHeight =
                        _sequenceHeight ?? initialSequenceHeight;

                    double logHeight = availableHeight - sequenceHeight;

                    // Respect minimum heights when enough space exists.
                    if (availableHeight >= minSequenceHeight + minLogHeight) {
                      sequenceHeight = _clamp(
                        sequenceHeight,
                        minSequenceHeight,
                        availableHeight - minLogHeight,
                      );

                      logHeight = availableHeight - sequenceHeight;
                    } else {
                      // On short viewports, use proportional sizing.
                      sequenceHeight = availableHeight * 0.60;
                      logHeight = availableHeight - sequenceHeight;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Access Sequence
                        SizedBox(
                          height: sequenceHeight,
                          child: const AccessSequenceWidget(),
                        ),

                        // Adjustable vertical divider
                        _buildHorizontalDivider(
                          onDrag: (delta) {
                            if (availableHeight <
                                minSequenceHeight + minLogHeight) {
                              return;
                            }

                            setState(() {
                              _sequenceHeight = _clamp(
                                sequenceHeight + delta,
                                minSequenceHeight,
                                availableHeight - minLogHeight,
                              );
                            });
                          },
                        ),

                        // Log / Statistics
                        SizedBox(
                          height: logHeight,
                          child: _buildLogStatistics(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // ========================================================
            // ADJUSTABLE VERTICAL DIVIDER
            // ========================================================
            _buildVerticalDivider(
              onDrag: (delta) {
                if (availableWidth < minLeftWidth + minMiddleWidth) {
                  return;
                }

                setState(() {
                  _leftWidth = _clamp(
                    left + delta,
                    minLeftWidth,
                    _min(maxLeftWidth, availableWidth - minMiddleWidth),
                  );
                });
              },
            ),

            // ========================================================
            // RIGHT COLUMN: MEMORY COMPONENTS
            // ========================================================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: const ComponentsArea(),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // Log / Statistics panel
  // ================================================================

  Widget _buildLogStatistics(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Center(
        child: Text(
          'Log / Statistics',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // ================================================================
  // Vertical divider: resizes left/right panes
  // ================================================================

  Widget _buildVerticalDivider({required ValueChanged<double> onDrag}) {
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
              width: 2,
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

  // ================================================================
  // Horizontal divider: resizes top/bottom panes
  // ================================================================

  Widget _buildHorizontalDivider({required ValueChanged<double> onDrag}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          onDrag(details.delta.dy);
        },
        child: SizedBox(
          height: dividerHeight,
          child: Center(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
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
}
