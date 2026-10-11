import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/layout/misc/access_sequence_modifier_dialog.dart';
import 'package:memory_access_simulator/layout/misc/configuration_dialog.dart';
import 'package:memory_access_simulator/layout/pages/page_mode.dart';
import 'package:memory_access_simulator/main.dart';

class BottomBarUI extends StatefulWidget {
  const BottomBarUI({super.key});

  @override
  State<BottomBarUI> createState() => _BottomBarUIState();
}

class _BottomBarUIState extends State<BottomBarUI> {
  final runtime = Runtime.singleton;
  bool get _isRunMode => pageModeNotifier.value == PageMode.run;

  // =====================================
  // MODE TRANSITIONS
  // =====================================

  void _enterRunMode() {
    setState(() => pageModeNotifier.value = PageMode.run);
  }

  void _returnToSetup() {
    setState(() => pageModeNotifier.value = PageMode.pause);
  }

  // =====================================
  // RUN FUNCTIONS
  // =====================================

  void _runAccess() {
    runtime.runAccess();
  }

  void _runMicroStep() {
    runtime.microRun();
  }

  void _stopSimulation() {
    // TODO: Stop simulation functionality.
  }

  void _download() {
    // TODO: Add export / download functionality.
  }

  // =====================================
  // STEP ITEM
  // =====================================

  Widget _stepItem({
    required BuildContext context,
    String? step,
    required String label,
    required String subLabel,
    required IconData icon,
    required VoidCallback onPressed,
    bool highlighted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // STEP INDICATOR
        if (step != null)
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),

        const SizedBox(width: 10),

        // ICON BUTTON
        Container(
          width: highlighted ? 64 : 54,
          height: highlighted ? 64 : 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                      color: Colors.black.withValues(alpha: 0.04),
                    ),
                  ]
                : [],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: highlighted ? 34 : 26),
            color: colorScheme.primary,
          ),
        ),

        const SizedBox(width: 12),

        // LABELS
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.bold,
                fontSize: highlighted ? 15 : 13,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: TextStyle(
                fontFamily: 'Roboto-Mono',
                fontSize: 11,
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _arrow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 24,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  // =====================================
  // BAR CONTAINER
  // =====================================

  Widget _buildBar({required Widget child, required Key key}) {
    return SizedBox(
      key: key,
      height: 90,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 12),
          child: child,
        ),
      ),
    );
  }

  // =====================================
  // SETUP BAR
  // =====================================

  Widget _buildSetupBar(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return _buildBar(
      key: const ValueKey('setup-bar'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepItem(
            context: context,
            step: '0',
            label: 'Configure',
            subLabel: 'set memory parameters',
            icon: Icons.tune_rounded,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => Transform.scale(
                  scale: (screenSize.height / 720),
                  child: const ConfigurationDialog(),
                ),
              );
            },
          ),

          _arrow(context),

          _stepItem(
            context: context,
            step: '1',
            label: 'Access Sequence',
            subLabel: 'modify memory instructions',
            icon: Icons.format_list_numbered,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => Transform.scale(
                  scale: (screenSize.height / 720),
                  child: const AccessSequenceModifierDialog(),
                ),
              );
            },
          ),

          _arrow(context),

          _stepItem(
            context: context,
            step: '2',
            label: 'Run',
            subLabel: 'switch to Run mode',
            icon: Icons.play_arrow_rounded,
            highlighted: true,
            onPressed: _enterRunMode,
          ),

          _arrow(context),

          _stepItem(
            context: context,
            step: '3',
            label: 'Reset',
            subLabel: 'clear all states',
            icon: Icons.restart_alt_rounded,
            onPressed: () => runtime.reset(),
          ),

          _arrow(context),

          _stepItem(
            context: context,
            step: '4',
            label: 'Download',
            subLabel: 'export results [SOON]',
            icon: Icons.download_rounded,
            onPressed: _download,
          ),
        ],
      ),
    );
  }

  // =====================================
  // RUN BAR
  // =====================================

  Widget _buildRunBar(BuildContext context) {
    return _buildBar(
      key: const ValueKey('run-bar'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // RETURN
          _stepItem(
            context: context,
            label: 'Return',
            subLabel: 'back to setup',
            icon: Icons.arrow_back_rounded,
            onPressed: _returnToSetup,
          ),

          SizedBox(width: 450),

          // RUN ONE MICRO-STEP
          _stepItem(
            context: context,
            label: 'Run Micro Step',
            subLabel: 'advance one micro-step',
            highlighted: true,
            icon: Icons.skip_next_rounded,
            onPressed: _runMicroStep,
          ),

          SizedBox(width: 450),

          // RUN COMPLETE ACCESS
          _stepItem(
            context: context,
            label: 'Run Access',
            subLabel: 'execute a full access',
            icon: Icons.fast_forward_rounded,
            onPressed: _runAccess,
          ),

          /* 
          // STOP
          _stepItem(
            context: context,
            label: 'Stop',
            subLabel: 'stop the simulation',
            icon: Icons.stop_rounded,
            onPressed: _stopSimulation,
          ), */
        ],
      ),
    );
  }

  // =====================================
  // BUILD
  // =====================================

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.18),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      child: _isRunMode ? _buildRunBar(context) : _buildSetupBar(context),
    );
  }
}
