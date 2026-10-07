import 'package:flutter/material.dart';

import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/core/components/memory.dart';

class DynamicMemoryWidget extends StatelessWidget {
  const DynamicMemoryWidget({super.key});

  static const double width = 520;
  static const double height = 420;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memory = Memory.singleton;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // Header
            // ============================================================
            Row(
              children: [
                Icon(
                  Icons.memory_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),

                const SizedBox(width: 8),

                Text(
                  'DRAM',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ============================================================
            // Physical pages
            // ============================================================
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: Runtime.singleton.accessNumber,
                builder: (context, _, __) {
                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.25,
                        ),
                    itemCount: memory.dynamic.length,
                    itemBuilder: (context, index) {
                      final page = memory.dynamic[index];

                      return _PhysicalPage(ppn: index, used: page.used);
                    },
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

// ======================================================================
// Physical page
// ======================================================================

class _PhysicalPage extends StatelessWidget {
  const _PhysicalPage({required this.ppn, required this.used});

  final int ppn;
  final bool used;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final borderColor = used
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: used
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor, width: used ? 1.5 : 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------------
          // PPN
          // ------------------------------------------------------------
          Row(
            children: [
              Icon(
                Icons.view_module_rounded,
                size: 15,
                color: used
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),

              const SizedBox(width: 5),

              Text(
                'P$ppn',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ------------------------------------------------------------
          // Used state
          // ------------------------------------------------------------
          Row(
            children: [
              Text(
                'USED',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const Spacer(),

              Container(
                width: 25,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  used ? '1' : '0',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 11,
                    color: used
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
