import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/layout/components/access_register.dart';
import 'package:memory_access_simulator/layout/components/address/physical_address_widget.dart';
import 'package:memory_access_simulator/layout/components/address/virtual_address_widget.dart';
import 'package:memory_access_simulator/layout/components/cache_widget.dart';
import 'package:memory_access_simulator/layout/components/connection_widget.dart';
import 'package:memory_access_simulator/layout/components/disk_widget.dart';
import 'package:memory_access_simulator/layout/components/dynamic_memory_widget.dart';
import 'package:memory_access_simulator/layout/components/mmu_widget.dart';
import 'package:memory_access_simulator/layout/components/page_table_widget.dart';
import 'package:memory_access_simulator/layout/components/tlb_widget.dart';

class ComponentsArea extends StatefulWidget {
  const ComponentsArea({super.key});

  /// Size of the virtual canvas.
  ///
  /// This is intentionally larger than the visible middle pane.
  static const double canvasWidth = 1680;
  static const double canvasHeight = 1080;

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
          // Workspace toolbar
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

          // Interactive workspace
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
                        // Background grid
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _WorkspaceGridPainter(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.4),
                            ),
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(350, 940),
                              Offset(595, 940),
                              Offset(595, 885),
                            ],
                            isOn: () => Runtime.singleton.connectVAtoTLB,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(350, 940),
                              Offset(1120, 940),
                              Offset(1120, 910),
                            ],
                            isOn: () => Runtime.singleton.connectVAtoPageTable,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(350, 940),
                              Offset(1600, 940),
                              Offset(1600, 510),
                            ],
                            isOn: () => Runtime.singleton.connectVAtoMMU,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(1580, 255),
                              Offset(1580, 235),
                            ],
                            isOn: () => Runtime.singleton.connectMMUtoDisk,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(1490, 140),
                              Offset(1370, 140),
                            ],
                            isOn: () => Runtime.singleton.connectDiskToDRAM,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(1370, 170),
                              Offset(1490, 170),
                            ],
                            isOn: () => Runtime.singleton.connectDRAMtoDisk,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(1560, 510),
                              Offset(1560, 760),
                              Offset(1370, 760),
                            ],
                            isOn: () => Runtime.singleton.connectMMUtoPageTable,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [Offset(870, 760), Offset(760, 760)],
                            isOn: () => Runtime.singleton.connectPageTableToTLB,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(440, 760),
                              Offset(220, 760),
                              Offset(220, 685),
                            ],
                            isOn: () => Runtime.singleton.connectTLBtoPA,
                            onColor: Colors.green,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [Offset(190, 830), Offset(190, 685)],
                            isOn: () => Runtime.singleton.connectVAtoPA,
                            onColor: theme.colorScheme.tertiary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(350, 540),
                              Offset(595, 540),
                              Offset(595, 485),
                            ],
                            isOn: () => Runtime.singleton.connectPAtoCache,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(350, 540),
                              Offset(1120, 540),
                              Offset(1120, 510),
                            ],
                            isOn: () => Runtime.singleton.connectPAtoDRAM,
                            onColor: Colors.green,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [Offset(870, 200), Offset(760, 200)],
                            isOn: () => Runtime.singleton.connectDRAMtoCache,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [Offset(760, 380), Offset(870, 380)],
                            isOn: () => Runtime
                                .singleton
                                .connectCacheToDRAMFromLineEviction,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [Offset(760, 420), Offset(870, 420)],
                            isOn: () => Runtime
                                .singleton
                                .connectCacheToDRAMFromLineEviction,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(440, 280),
                              Offset(190, 280),
                              Offset(190, 150),
                            ],
                            isOn: () =>
                                Runtime.singleton.connectCacheToAccessRegister,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        Positioned.fill(
                          child: ConnectionWidget(
                            points: const [
                              Offset(190, 150),
                              Offset(190, 280),
                              Offset(440, 280),
                            ],
                            isOn: () =>
                                Runtime.singleton.connectAccessRegisterToCache,
                            onColor: theme.colorScheme.primary,
                          ),
                        ),

                        ////// COMPONENTS ///////
                        Positioned(
                          left: 40,
                          top: 40,
                          width: 300,
                          child: AccessRegisterWidget(),
                        ),

                        Positioned(
                          left: 40,
                          top: 420,
                          width: 300,
                          child: PhysicalAddressWidget(),
                        ),

                        Positioned(
                          left: 40,
                          top: 840,
                          width: 300,
                          child: VirtualAddressWidget(),
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

                        Positioned(
                          left: 1500,
                          top: 80,
                          child: const DiskWidget(),
                        ),

                        Positioned(
                          left: 1500,
                          top: 260,
                          child: const MMUWidget(),
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

// Dotted
class _WorkspaceGridPainter extends CustomPainter {
  const _WorkspaceGridPainter({required this.color});

  final Color color;

  static const double spacing = 40;
  static const double dotRadius = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = 0; x <= size.width; x += spacing) {
      for (double y = 0; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WorkspaceGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
