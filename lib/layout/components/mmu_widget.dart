import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/memory.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';

class MMUWidget extends StatefulWidget {
  const MMUWidget({super.key});

  static const double width = 150;
  static const double height = 240;

  @override
  State<MMUWidget> createState() => _MMUWidgetState();
}

class _MMUWidgetState extends State<MMUWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: MMUWidget.width,
      height: MMUWidget.height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.memory_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'MMU',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Table
          Expanded(
            child: ListenableBuilder(
              listenable: Runtime.singleton,
              builder: (context, _) {
                final entries = Memory.singleton.dynamic;

                return Column(
                  children: [
                    // Column header
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Center(
                              child: Text(
                                'PPN',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _headerCell(context, 'U'),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: _headerCell(context, 'LAST'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Scrollable page entries
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        thickness: 6,
                        radius: const Radius.circular(10),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final runtime = Runtime.singleton;
                            final bool isPageAccessed =
                                entry.used && (runtime.getPPN == index);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  // Page number outside the entry.
                                  SizedBox(
                                    width: 48,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$index',
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Stored DRAM page data.
                                  Expanded(
                                    child: Container(
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: isPageAccessed
                                            ? colors.primary.withValues(
                                                alpha: 0.06,
                                              )
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isPageAccessed
                                              ? colors.primary.withValues(
                                                  alpha: 0.35,
                                                )
                                              : colors.outline.withValues(
                                                  alpha: 0.35,
                                                ),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: _stateCell(
                                              context,
                                              entry.used,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: _dataCell(
                                              context,
                                              '${entry.lastAccess}',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

  Widget _headerCell(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 32,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _dataCell(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
      ),
    );
  }

  Widget _stateCell(BuildContext context, bool value) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: value ? colors.primary : colors.outline),
          color: value
              ? colors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          value ? '1' : '0',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: value ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
