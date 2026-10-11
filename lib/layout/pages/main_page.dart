import 'package:flutter/material.dart';
import 'package:memory_access_simulator/layout/components/access_sequence_widget.dart';
import 'package:memory_access_simulator/layout/components/components_area.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

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
              screenSize: screenSize,
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
            child: _FittedPane(
              width: 1080,
              height: 720,
              screenSize: screenSize,
              child: const ComponentsArea(),
            ),
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
              screenSize: screenSize,
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
    required this.screenSize,
  });

  final double width;
  final double height;
  final Widget child;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: width,
          height: height,
          child: Transform.scale(
            scale: (screenSize.height / 720),
            child: child,
          ),
        ),
      ),
    );
  }
}
