import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:memory_access_simulator/layout/components/address/physical_address_widget.dart';
import 'package:memory_access_simulator/layout/components/address/virtual_address_widget.dart';
import 'package:memory_access_simulator/layout/components/cache_widget.dart';
import 'package:memory_access_simulator/layout/components/dynamic_memory_widget.dart';
import 'package:memory_access_simulator/layout/components/page_table_widget.dart';
import 'package:memory_access_simulator/layout/components/tlb_widget.dart';

class ComponentsArea extends StatefulWidget {
  const ComponentsArea({super.key});

  /// Size of the virtual canvas.
  ///
  /// This is intentionally larger than the visible middle pane.
  static const double canvasWidth = 1600;
  static const double canvasHeight = 1000;

  @override
  State<ComponentsArea> createState() => _ComponentsAreaState();
}

class _ComponentsAreaState extends State<ComponentsArea> {
  final TransformationController _transformationController =
      TransformationController();

  // Add the other components here later.
  //
  // Offset _cachePosition = const Offset(50, 400);
  // Offset _physicalMemoryPosition = const Offset(500, 400);

  // ------------------------------------------------------------
  // Workspace configuration
  // ------------------------------------------------------------

  static const double minScale = 0.5;
  static const double maxScale = 2.5;

  // ------------------------------------------------------------
  // Zoom
  // ------------------------------------------------------------

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    final newScale = math.min(currentScale * 1.2, maxScale);

    _setScale(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    final newScale = math.max(currentScale / 1.2, minScale);

    _setScale(newScale);
  }

  void _setScale(double scale) {
    final current = _transformationController.value;

    final translation = current.getTranslation();

    final matrix = Matrix4.identity()
      ..translate(translation.x, translation.y)
      ..scale(scale);

    _transformationController.value = matrix;
  }

  // ------------------------------------------------------------
  // Fit entire canvas into viewport
  // ------------------------------------------------------------

  void _fitToView(BoxConstraints constraints) {
    final viewportWidth = constraints.maxWidth;
    final viewportHeight = constraints.maxHeight;

    if (!viewportWidth.isFinite || !viewportHeight.isFinite) {
      return;
    }

    final scaleX = viewportWidth / ComponentsArea.canvasWidth;

    final scaleY = viewportHeight / ComponentsArea.canvasHeight;

    final scale = math.min(math.min(scaleX, scaleY), maxScale);

    final offsetX = (viewportWidth - ComponentsArea.canvasWidth * scale) / 2;

    final offsetY = (viewportHeight - ComponentsArea.canvasHeight * scale) / 2;

    final matrix = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(scale);

    _transformationController.value = matrix;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ============================================================
          // Workspace toolbar
          // ============================================================
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),

                  const SizedBox(width: 8),

                  Text(
                    'Memory System',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const Spacer(),

                  // Zoom out
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: _zoomOut,
                    icon: const Icon(Icons.remove_rounded, size: 19),
                  ),

                  // Fit
                  IconButton(
                    tooltip: 'Fit to view',
                    onPressed: () {
                      final renderBox =
                          context.findRenderObject() as RenderBox?;

                      if (renderBox == null) {
                        return;
                      }

                      final toolbarHeight = 48.0;

                      final width = renderBox.size.width;
                      final height = renderBox.size.height - toolbarHeight;

                      _fitToView(
                        BoxConstraints.tightFor(width: width, height: height),
                      );
                    },
                    icon: const Icon(Icons.fit_screen_rounded, size: 19),
                  ),

                  // Zoom in
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: _zoomIn,
                    icon: const Icon(Icons.add_rounded, size: 19),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, thickness: 1, color: theme.colorScheme.outline),

          // ============================================================
          // Interactive workspace
          // ============================================================
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  transformationController: _transformationController,
                  panEnabled: true,
                  scaleEnabled: false,
                  minScale: 0.5,
                  maxScale: 2.5,
                  boundaryMargin: const EdgeInsets.all(300),
                  constrained: false,
                  child: SizedBox(
                    width: ComponentsArea.canvasWidth,
                    height: ComponentsArea.canvasHeight,
                    child: Stack(
                      children: [
                        // ============================================================
                        // Background grid
                        // ============================================================
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _WorkspaceGridPainter(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.12),
                            ),
                          ),
                        ),

                        Positioned(
                          left: 40,
                          top: 760,
                          width: 300,
                          child: VirtualAddressWidget(),
                        ),

                        Positioned(
                          left: 40,
                          top: 320,
                          width: 300,
                          child: PhysicalAddressWidget(),
                        ),

                        Positioned(
                          left: 450,
                          top: 110,
                          child: const CacheWidget(),
                        ),

                        Positioned(
                          left: 450,
                          top: 630,
                          child: const TLBWidget(),
                        ),

                        Positioned(
                          left: 880,
                          top: 600,
                          child: const PageTableWidget(),
                        ),
                        Positioned(
                          left: 880,
                          top: 80,
                          child: const DynamicMemoryWidget(),
                        ),

                        // Cache
                        // Physical Memory
                        // etc.
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Workspace grid
// ================================================================

class _WorkspaceGridPainter extends CustomPainter {
  const _WorkspaceGridPainter({required this.color});

  final Color color;

  static const double spacing = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_WorkspaceGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
