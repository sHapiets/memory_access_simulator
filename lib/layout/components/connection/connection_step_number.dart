import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/connection.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';

class ConnectionStepNumber extends StatefulWidget {
  final Connection Function() connection;

  const ConnectionStepNumber({super.key, required this.connection});

  @override
  State<ConnectionStepNumber> createState() => _ConnectionStepNumberState();
}

class _ConnectionStepNumberState extends State<ConnectionStepNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.5,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
    ]).animate(_scaleController);

    Runtime.singleton.addListener(_handleRuntimeChange);
  }

  void _handleRuntimeChange() {
    final connection = widget.connection();
    final currentMicroStep = Runtime.singleton.microStepNumber;

    final isCurrentConnection =
        connection.active && connection.microStepNumber == currentMicroStep;

    if (isCurrentConnection) {
      if (!_scaleController.isAnimating) {
        _scaleController.repeat();
      }
    } else {
      if (_scaleController.isAnimating || _scaleController.value != 0) {
        _scaleController.stop();
        _scaleController.reset();
      }
    }
  }

  @override
  void dispose() {
    Runtime.singleton.removeListener(_handleRuntimeChange);
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Runtime.singleton,
      builder: (context, _) {
        final connection = widget.connection();
        final isInvalidStep = connection.microStepNumber == -1;

        final isCurrentConnection =
            connection.active &&
            connection.microStepNumber == Runtime.singleton.microStepNumber;

        final color = theme.colorScheme.onSurface.withAlpha(
          isInvalidStep ? 40 : 255,
        );

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final pulse = isCurrentConnection ? _animation.value : 1.0;

            return Container(
              constraints: BoxConstraints(minWidth: 32),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 2,
                  color: isInvalidStep
                      ? theme.colorScheme.outline.withAlpha(25)
                      : color.withAlpha((255 * pulse).floor()),
                ),
              ),
              child: Text(
                isInvalidStep ? '--' : connection.microStepNumber.toString(),
                style: TextStyle(
                  color: isInvalidStep
                      ? theme.colorScheme.outline.withAlpha(25)
                      : color.withAlpha((255 * pulse).floor()),
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }
}
