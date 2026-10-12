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
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final iconSize = compact
        ? (highlighted ? 26.0 : 21.0)
        : (highlighted ? 30.0 : 24.0);

    final buttonSize = compact
        ? (highlighted ? 48.0 : 42.0)
        : (highlighted ? 56.0 : 48.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (step != null) ...[
          Container(
            width: compact ? 18 : 22,
            height: compact ? 18 : 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 9 : 11,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
        ],

        // ICON BUTTON
        Container(
          width: buttonSize,
          height: buttonSize,
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.expand(),
            onPressed: onPressed,
            icon: Icon(icon, size: iconSize),
            color: colorScheme.primary,
          ),
        ),

        SizedBox(width: compact ? 7 : 12),

        // LABELS
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : (highlighted ? 15 : 13),
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto-Mono',
                  fontSize: compact ? 9 : 11,
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =====================================
  // BAR CONTAINER
  // =====================================

  Widget _buildBar({required Widget child, required Key key}) {
    return SizedBox(
      key: key,
      height: 90,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }

  // =====================================
  // SETUP BAR
  // =====================================

  Widget _buildSetupBar(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 1150;
        final tiny = width < 800;

        Widget step({
          required String number,
          required String label,
          required String subLabel,
          required IconData icon,
          required VoidCallback onPressed,
          bool highlighted = false,
        }) {
          return Expanded(
            child: _stepItem(
              context: context,
              step: number,
              label: label,
              subLabel: subLabel,
              icon: icon,
              onPressed: onPressed,
              highlighted: highlighted,
              compact: compact,
            ),
          );
        }

        Widget arrow() {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tiny ? 3 : (compact ? 6 : 12),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: compact ? 17 : 22,
              color: Theme.of(context).colorScheme.outline,
            ),
          );
        }

        return _buildBar(
          key: const ValueKey('setup-bar'),
          child: Row(
            children: [
              step(
                number: '0',
                label: 'Configure',
                subLabel: 'set memory parameters',
                icon: Icons.tune_rounded,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => Transform.scale(
                      scale: screenSize.height / 720,
                      child: const ConfigurationDialog(),
                    ),
                  );
                },
              ),
              arrow(),
              step(
                number: '1',
                label: 'Access Sequence',
                subLabel: 'modify memory instructions',
                icon: Icons.format_list_numbered,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => Transform.scale(
                      scale: screenSize.height / 720,
                      child: const AccessSequenceModifierDialog(),
                    ),
                  );
                },
              ),
              arrow(),
              step(
                number: '2',
                label: 'Run',
                subLabel: 'switch to Run mode',
                icon: Icons.play_arrow_rounded,
                highlighted: true,
                onPressed: _enterRunMode,
              ),
              arrow(),
              step(
                number: '3',
                label: 'Reset',
                subLabel: 'clear all states',
                icon: Icons.restart_alt_rounded,
                onPressed: () => runtime.reset(),
              ),
              if (!tiny) ...[
                arrow(),
                step(
                  number: '4',
                  label: 'Download',
                  subLabel: 'export results [SOON]',
                  icon: Icons.download_rounded,
                  onPressed: _download,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // =====================================
  // RUN BAR
  // =====================================

  Widget _buildRunBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;

        return _buildBar(
          key: const ValueKey('run-bar'),
          child: Row(
            children: [
              _stepItem(
                context: context,
                label: 'Return',
                subLabel: 'back to setup',
                icon: Icons.arrow_back_rounded,
                onPressed: _returnToSetup,
                compact: compact,
              ),

              SizedBox(width: 16),
              Center(
                child: _stepItem(
                  context: context,
                  label: 'Run Micro Step',
                  subLabel: 'advance one micro-step',
                  highlighted: true,
                  icon: Icons.skip_next_rounded,
                  onPressed: _runMicroStep,
                  compact: compact,
                ),
              ),
              SizedBox(width: 16),

              Align(
                alignment: Alignment.centerRight,
                child: _stepItem(
                  context: context,
                  label: 'Run Access',
                  subLabel: 'execute a full access',
                  icon: Icons.fast_forward_rounded,
                  onPressed: _runAccess,
                  compact: compact,
                ),
              ),
            ],
          ),
        );
      },
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
