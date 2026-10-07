import 'package:flutter/material.dart';
import 'package:memory_access_simulator/layout/components/access_sequence_widget.dart';
import 'package:memory_access_simulator/layout/components/components_area.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ============================================================
        // Left — Access sequence
        // ============================================================
        Expanded(
          flex: 8,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _FittedPane(
              width: 300,
              height: 700,
              child: const AccessSequenceWidget(),
            ),
          ),
        ),

        // ============================================================
        // Middle — Interactive components area
        // ============================================================
        Expanded(
          flex: 25,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: const ComponentsArea(),
          ),
        ),

        // ============================================================
        // Right — Access log
        // ============================================================
        Expanded(
          flex: 10,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _FittedPane(
              width: 450,
              height: 700,
              child: Center(child: const Text('Log/Statistics')),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// Fixed-size pane that scales uniformly
// ================================================================

class _FittedPane extends StatelessWidget {
  const _FittedPane({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );
  }
}
