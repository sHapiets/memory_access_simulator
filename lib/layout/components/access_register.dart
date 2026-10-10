import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';

class AccessRegisterWidget extends StatelessWidget {
  const AccessRegisterWidget({super.key});

  static const double width = 240;
  static const double height = 100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.app_registration_rounded,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Access Register',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Current access type
            Expanded(
              child: ListenableBuilder(
                listenable: Runtime.singleton,
                builder: (context, _) {
                  final sequence = AccessSequence.singleton.sequence;
                  final pointer = AccessSequence.singleton.pointer;

                  final hasCurrentAccess =
                      pointer >= 0 && pointer < sequence.length;

                  final accessType = hasCurrentAccess
                      ? sequence[pointer].type.toString().split('.').last
                      : '--';

                  return Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasCurrentAccess
                          ? colors.primary.withValues(alpha: 0.08)
                          : colors.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasCurrentAccess
                            ? colors.primary.withValues(alpha: 0.4)
                            : colors.outline.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      accessType,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: hasCurrentAccess
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
