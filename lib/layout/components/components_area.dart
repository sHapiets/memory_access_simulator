import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/foundation/access.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';
import 'package:memory_access_simulator/layout/components/access_register.dart';
import 'package:memory_access_simulator/layout/components/address/physical_address_widget.dart';
import 'package:memory_access_simulator/layout/components/address/virtual_address_widget.dart';
import 'package:memory_access_simulator/layout/components/component_dialog/show_in_dialog_button.dart';
import 'package:memory_access_simulator/layout/components/cache_widget.dart';
import 'package:memory_access_simulator/layout/components/component_dialog/tap_to_show_in_dialog.dart';
import 'package:memory_access_simulator/layout/components/connection/connection_step_number.dart';
import 'package:memory_access_simulator/layout/components/connection/connection_widget.dart';
import 'package:memory_access_simulator/layout/components/disk_widget.dart';
import 'package:memory_access_simulator/layout/components/dynamic_memory_widget.dart';
import 'package:memory_access_simulator/layout/components/mmu_widget.dart';
import 'package:memory_access_simulator/layout/components/page_table_widget.dart';
import 'package:memory_access_simulator/layout/components/tlb_widget.dart';
import 'package:memory_access_simulator/layout/misc/broken_line_container.dart';
import 'package:memory_access_simulator/layout/pages/page_mode.dart';
import 'package:memory_access_simulator/main.dart';

class ComponentsArea extends StatefulWidget {
  const ComponentsArea({super.key});

  /// Size of the virtual canvas.
  ///
  /// This is intentionally larger than the visible middle pane.
  static const double canvasWidth = 1980;
  static const double canvasHeight = 1080;

  @override
  State<ComponentsArea> createState() => _ComponentsAreaState();
}

class _ComponentsAreaState extends State<ComponentsArea>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();

  // Add the other components here later.
  //
  // Offset _cachePosition = const Offset(50, 400);
  // Offset _physicalMemoryPosition = const Offset(500, 400);

  // ------------------------------------------------------------
  // Workspace configuration
  // ------------------------------------------------------------

  static const double minScale = 0.1;
  static const double maxScale = 3;

  bool _initialFitScheduled = false;

  // Zoom is enabled only while the pointer is over empty workspace space.
  bool _isHoveringComponent = false;

  void _setComponentHover(bool hovering) {
    if (_isHoveringComponent == hovering) return;

    setState(() {
      _isHoveringComponent = hovering;
    });
  }

  late final AnimationController _zoomController;

  Animation<Matrix4>? _zoomAnimation;

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

    _animateTo(matrix);
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

    _animateTo(matrix);
  }

  void _animateTo(Matrix4 target) {
    _zoomController.stop();

    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value.clone(),
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _zoomController.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();

    _zoomController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
        )..addListener(() {
          final animation = _zoomAnimation;
          if (animation != null) {
            _transformationController.value = animation.value;
          }
        });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder(
      valueListenable: pageModeNotifier,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (value == PageMode.run)
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
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
                ],
              ),
            ),
          ),

          Divider(height: 1, thickness: 1, color: theme.colorScheme.outline),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final overlayScale = math
                    .min(
                      constraints.maxWidth / 900,
                      constraints.maxHeight / 700,
                    )
                    .clamp(0.85, 1.65)
                    .toDouble();

                if (!_initialFitScheduled) {
                  _initialFitScheduled = true;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _fitToView(constraints);
                  });
                }

                return Stack(
                  children: [
                    // Interactive workspace
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        panEnabled: true,
                        scaleEnabled: !_isHoveringComponent,
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
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(420, 940),
                                    Offset(750, 940),
                                    Offset(750, 895),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectVAtoTLB,
                                  onColor: theme.colorScheme.onSurface,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(420, 940),
                                    Offset(1330, 940),
                                    Offset(1330, 915),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectVAtoPageTable,
                                  onColor: theme.colorScheme.onSurface,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(420, 940),
                                    Offset(1880, 940),
                                    Offset(1880, 515),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectVAtoMMU,
                                  onColor: theme.colorScheme.onSurface,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(1860, 255),
                                    Offset(1860, 245),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectMMUtoDisk,
                                  onColor: theme.colorScheme.onSurface,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(1760, 140),
                                    Offset(1600, 140),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectDiskToDRAM,
                                  onColor: theme.colorScheme.primary,
                                  isDotted: true,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(1590, 170),
                                    Offset(1760, 170),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectDRAMtoDisk,
                                  isDotted: true,
                                  onColor: theme.colorScheme.primary,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(1840, 510),
                                    Offset(1840, 760),
                                    Offset(1600, 760),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectMMUtoPageTable,
                                  onColor: Colors.green,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(1070, 730),
                                    Offset(960, 730),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectPageTableToTLB,
                                  onColor: Colors.green,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(1070, 790),
                                    Offset(960, 790),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectPageTableToTLB,
                                  onColor: theme.colorScheme.onSurface,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(540, 760),
                                    Offset(230, 760),
                                    Offset(230, 715),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectTLBtoPA,
                                  onColor: Colors.green,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(190, 795),
                                    Offset(190, 715),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectVAtoPA,
                                  onColor: Colors.pink.withAlpha(120),
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(420, 540),
                                    Offset(770, 540),
                                    Offset(770, 507),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectPAtoCache,
                                  onColor: theme.colorScheme.tertiary
                                      .withValues(alpha: 0.8),
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(420, 540),
                                    Offset(750, 540),
                                    Offset(750, 507),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectPAtoCache,
                                  onColor: theme.colorScheme.secondary
                                      .withValues(alpha: 0.8),
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(420, 540),
                                    Offset(730, 540),
                                    Offset(730, 507),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectPAtoCache,
                                  onColor: Colors.blueAccent.withAlpha(180),
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(420, 540),
                                    Offset(1330, 540),
                                    Offset(1330, 515),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectPAtoDRAM,
                                  onColor: Colors.green,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(1070, 200),
                                    Offset(960, 200),
                                  ],
                                  connection: () =>
                                      Runtime.singleton.connectDRAMtoCache,
                                  onColor: theme.colorScheme.primary,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(950, 380),
                                    Offset(1060, 380),
                                  ],
                                  connection: () => Runtime
                                      .singleton
                                      .connectCacheToDRAMFromLineEviction,
                                  onColor: theme.colorScheme.primary,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(950, 420),
                                    Offset(1060, 420),
                                  ],
                                  connection: () => Runtime
                                      .singleton
                                      .connectCacheToDRAMFromPageEviction,
                                  isDotted: true,
                                  onColor: theme.colorScheme.primary,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(540, 290),
                                    Offset(210, 290),
                                    Offset(210, 160),
                                  ],
                                  connection: () => Runtime
                                      .singleton
                                      .connectCacheToAccessRegister,
                                  onColor: theme.colorScheme.primary,
                                ),
                              ),

                              Positioned.fill(
                                child: ConnectionWidget(
                                  points: const [
                                    Offset(210, 150),
                                    Offset(210, 290),
                                    Offset(530, 290),
                                  ],
                                  connection: () => Runtime
                                      .singleton
                                      .connectAccessRegisterToCache,
                                  onColor: theme.colorScheme.primary,
                                ),
                              ),

                              //// LAYOUT ELEMENTS
                              /// DRAM BOX
                              Positioned(
                                left: 1040,
                                top: 40,
                                child: BrokenLineContainer(
                                  title: 'DRAM',
                                  width: 580,
                                  height: 910,
                                  dashLength: 6,
                                  gapLength: 12,
                                ),
                              ),

                              //// CONNECTION STEP NUMBERS
                              Positioned(
                                left: 700,
                                top: 897,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectVAtoTLB,
                                ),
                              ),

                              Positioned(
                                left: 1275,
                                top: 897,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectVAtoPageTable,
                                ),
                              ),

                              Positioned(
                                left: 1900,
                                top: 500,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectVAtoMMU,
                                ),
                              ),

                              Positioned(
                                left: 1660,
                                top: 90,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectDiskToDRAM,
                                ),
                              ),

                              Positioned(
                                left: 1660,
                                top: 180,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectDRAMtoDisk,
                                ),
                              ),

                              Positioned(
                                left: 1660,
                                top: 710,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectMMUtoPageTable,
                                ),
                              ),

                              Positioned(
                                left: 1000,
                                top: 740,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectPageTableToTLB,
                                ),
                              ),

                              Positioned(
                                left: 670,
                                top: 497,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectPAtoCache,
                                ),
                              ),

                              Positioned(
                                left: 1275,
                                top: 497,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectPAtoDRAM,
                                ),
                              ),

                              Positioned(
                                left: 995,
                                top: 155,
                                child: ConnectionStepNumber(
                                  connection: () =>
                                      Runtime.singleton.connectDRAMtoCache,
                                ),
                              ),
                              Positioned(
                                left: 995,
                                top: 335,
                                child: ConnectionStepNumber(
                                  connection: () => Runtime
                                      .singleton
                                      .connectCacheToDRAMFromLineEviction,
                                ),
                              ),

                              Positioned(
                                left: 995,
                                top: 420,
                                child: ConnectionStepNumber(
                                  connection: () => Runtime
                                      .singleton
                                      .connectCacheToDRAMFromPageEviction,
                                ),
                              ),

                              Positioned(
                                left: 225,
                                top: 240,
                                child: ConnectionStepNumber(
                                  connection: () => Runtime
                                      .singleton
                                      .connectCacheToAccessRegister,
                                ),
                              ),

                              Positioned(
                                left: 225,
                                top: 240,
                                child: ConnectionStepNumber(
                                  connection: () => Runtime
                                      .singleton
                                      .connectAccessRegisterToCache,
                                ),
                              ),

                              ////// COMPONENTS ///////
                              Positioned(
                                left: 60,
                                top: 40,
                                width: 300,
                                child: AccessRegisterWidget(),
                              ),

                              Positioned(
                                left: 20,
                                top: 350,
                                width: 390,
                                child: TapToShowInDialog(
                                  child: PhysicalAddressWidget(),
                                ),
                              ),

                              Positioned(
                                left: 20,
                                top: 800,
                                width: 390,
                                child: TapToShowInDialog(
                                  child: VirtualAddressWidget(),
                                ),
                              ),

                              Positioned(
                                left: 550,
                                top: 100,
                                height: 390,
                                width: 390,
                                child: MouseRegion(
                                  onEnter: (_) => _setComponentHover(true),
                                  onExit: (_) => _setComponentHover(false),
                                  child: TapToShowInDialog(
                                    child: const CacheWidget(),
                                  ),
                                ),
                              ),

                              Positioned(
                                left: 550,
                                top: 600,
                                width: 390,
                                height: 280,
                                child: MouseRegion(
                                  onEnter: (_) => _setComponentHover(true),
                                  onExit: (_) => _setComponentHover(false),
                                  child: TapToShowInDialog(
                                    child: const TLBWidget(),
                                  ),
                                ),
                              ),

                              Positioned(
                                left: 1080,
                                top: 580,
                                width: 500,
                                height: 320,
                                child: MouseRegion(
                                  onEnter: (_) => _setComponentHover(true),
                                  onExit: (_) => _setComponentHover(false),
                                  child: TapToShowInDialog(
                                    child: const PageTableWidget(),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 1080,
                                top: 80,
                                height: 420,
                                width: 500,
                                child: MouseRegion(
                                  onEnter: (_) => _setComponentHover(true),
                                  onExit: (_) => _setComponentHover(false),
                                  child: TapToShowInDialog(
                                    child: const DynamicMemoryWidget(),
                                  ),
                                ),
                              ),

                              Positioned(
                                left: 1780,
                                top: 80,
                                child: const DiskWidget(),
                              ),

                              Positioned(
                                left: 1762,
                                top: 260,
                                width: 190,
                                height: 240,
                                child: MouseRegion(
                                  onEnter: (_) => _setComponentHover(true),
                                  onExit: (_) => _setComponentHover(false),
                                  child: TapToShowInDialog(
                                    child: const MMUWidget(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Transform.scale(
                        scale: overlayScale,
                        alignment: Alignment.bottomRight,
                        child: _Legend(),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Transform.scale(
                        scale: overlayScale,
                        alignment: Alignment.topRight,
                        child: ZoomControls(
                          onZoomIn: _zoomIn,
                          onZoomOut: _zoomOut,
                          onFitToScreen: () {
                            final renderBox =
                                context.findRenderObject() as RenderBox?;

                            if (renderBox == null) return;

                            _fitToView(
                              BoxConstraints.tightFor(
                                width: renderBox.size.width,
                                height: renderBox.size.height,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: Transform.scale(
                          scale: overlayScale * 1.3,
                          alignment: Alignment.bottomCenter,
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              Runtime.singleton,
                              AccessSequence.singleton,
                            ]),
                            builder: (context, _) {
                              final runtime = Runtime.singleton;
                              final sequence =
                                  AccessSequence.singleton.sequence;
                              final pointer = AccessSequence.singleton.pointer;

                              final Access? currentAccess =
                                  pointer >= 0 && pointer < sequence.length
                                  ? sequence[pointer]
                                  : null;

                              return WorkspaceStatusBar(
                                pointer: pointer,
                                currentAccess: currentAccess,
                                cacheHit: runtime.cacheHit,
                                cacheMiss: runtime.cacheMiss,
                                tlbHit: runtime.tlbHit,
                                tlbMiss: runtime.tlbMiss,
                                pageFault: runtime.pageFault,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
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

class WorkspaceStatusBar extends StatelessWidget {
  const WorkspaceStatusBar({
    super.key,
    required this.pointer,
    required this.currentAccess,
    required this.cacheHit,
    required this.cacheMiss,
    required this.tlbHit,
    required this.tlbMiss,
    required this.pageFault,
  });

  final int pointer;
  final Access? currentAccess;
  final bool cacheHit;
  final bool cacheMiss;
  final bool tlbHit;
  final bool tlbMiss;
  final bool pageFault;

  String _formatAddress(int address) {
    return '0x${address.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final accessNumber = pointer < 0 ? '--' : '${pointer + 1}';

    final accessType = currentAccess == null
        ? '--'
        : currentAccess!.type == AccessType.load
        ? 'LOAD'
        : 'STORE';

    final address = currentAccess == null
        ? '--'
        : _formatAddress(currentAccess!.address);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surface.withAlpha(240),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          // Access number
          _StatusLabel(label: 'Access', value: accessNumber),

          _separator(context),

          // Current access type
          _StatusLabel(
            label: 'Type',
            value: accessType,
            valueColor: currentAccess == null
                ? colors.onSurfaceVariant
                : currentAccess!.type == AccessType.load
                ? colors.secondary
                : colors.tertiary,
          ),

          // Current virtual address
          _StatusLabel(label: 'Address', value: address, monospace: true),

          _separator(context),

          // Cache status
          _AccessInfo(label: 'Cache', hit: cacheHit, miss: cacheMiss),

          _separator(context),

          // TLB status
          _AccessInfo(label: 'TLB', hit: tlbHit, miss: tlbMiss),

          _separator(context),

          // Page fault status
          _StatusLabel(
            label: 'Page Fault',
            value: pageFault ? 'YES' : '--',
            valueColor: pageFault ? Colors.red : colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _separator(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

// ================================================================
// GENERIC STATUS LABEL
// ================================================================

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontFamily: monospace ? 'Roboto-Mono' : 'Nunito',
            fontWeight: FontWeight.bold,
            color: valueColor ?? colors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// CACHE / TLB STATUS
// ================================================================

class _AccessInfo extends StatelessWidget {
  const _AccessInfo({
    required this.label,
    required this.hit,
    required this.miss,
  });

  final String label;
  final bool hit;
  final bool miss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Color statusColor;
    final String status;

    if (hit) {
      statusColor = Colors.green;
      status = 'HIT';
    } else if (miss) {
      statusColor = Colors.red;
      status = 'MISS';
    } else {
      statusColor = colors.onSurfaceVariant;
      status = '--';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
        ),
        const SizedBox(width: 4),
        Text(
          status,
          style: theme.textTheme.labelMedium?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withAlpha(180),
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Legend', style: Theme.of(context).textTheme.bodySmall),
            SizedBox(height: 10),
            _LegendItem(color: theme.colorScheme.onSurface, label: 'VPN'),
            _LegendItem(
              color: const Color.fromRGBO(76, 175, 80, 1),
              label: 'PPN',
            ),
            _LegendItem(
              color: Colors.pink.withAlpha(200),
              label: 'PAGE OFFSET',
            ),
            _LegendItem(color: theme.colorScheme.primary, label: 'DATA'),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitToScreen,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitToScreen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomButton(
              icon: Icons.add_rounded,
              tooltip: 'Zoom in',
              onPressed: onZoomIn,
            ),
            _ZoomButton(
              icon: Icons.fit_screen_rounded,
              tooltip: 'Fit to screen',
              onPressed: onFitToScreen,
            ),
            _ZoomButton(
              icon: Icons.remove_rounded,
              tooltip: 'Zoom out',
              onPressed: onZoomOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
