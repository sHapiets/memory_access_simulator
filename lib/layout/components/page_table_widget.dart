import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/memory.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';

class PageTableWidget extends StatefulWidget {
  const PageTableWidget({super.key});

  static const double width = 480;
  static const double height = 300;

  @override
  State<PageTableWidget> createState() => _PageTableWidgetState();
}

class _PageTableWidgetState extends State<PageTableWidget> {
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
      width: PageTableWidget.width,
      height: PageTableWidget.height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.table_rows_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Page Table',
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
                final entries = Memory.singleton.pageTable;

                return Column(
                  children: [
                    // Column header
                    Row(
                      children: [
                        // VPN header - outside table
                        SizedBox(
                          width: 70,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Center(
                              child: Text(
                                'VPN',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Actual table header
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colors.outline.withValues(alpha: 0.45),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: _headerCell(context, 'V')),
                                Expanded(child: _headerCell(context, 'D')),
                                Expanded(
                                  flex: 5,
                                  child: _headerCell(context, 'PPN'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // ONE scrollable list for both VPN and table rows.
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

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // VPN label is OUTSIDE the table.
                                  SizedBox(
                                    width: 70,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
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

                                  // Stored page-table data.
                                  Expanded(
                                    child: Container(
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: entry.valid
                                            ? colors.primary.withValues(
                                                alpha: 0.06,
                                              )
                                            : colors.surfaceContainerHighest
                                                  .withValues(alpha: 0.35),
                                        border: Border.all(
                                          color: entry.valid
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
                                            child: _stateCell(
                                              context,
                                              entry.valid,
                                            ),
                                          ),
                                          Expanded(
                                            child: _stateCell(
                                              context,
                                              entry.dirty,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 5,
                                            child: _dataCell(
                                              context,
                                              entry.valid
                                                  ? '${entry.ppn}'
                                                  : '--',
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
          color: value
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceContainerHighest,
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
