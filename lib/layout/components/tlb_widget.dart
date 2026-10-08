import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/tlb.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/foundation/tlb_entry.dart';

class TLBWidget extends StatefulWidget {
  const TLBWidget({super.key});

  static const double width = 300;
  static const double height = 240;

  @override
  State<TLBWidget> createState() => _TLBWidgetState();
}

class _TLBWidgetState extends State<TLBWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tlb = TLB.singleton;

    return SizedBox(
      width: TLBWidget.width,
      height: TLBWidget.height,
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
            // --------------------------------------------------
            // Component header
            // --------------------------------------------------
            Row(
              children: [
                Icon(
                  Icons.memory_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'TLB',
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

            // --------------------------------------------------
            // TLB table
            // --------------------------------------------------
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Column headers
                    const _HeaderRow(),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outline,
                    ),

                    // Scrollable entries
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Runtime.singleton,
                        builder: (context, _) {
                          return Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            thickness: 6,
                            radius: const Radius.circular(10),
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.zero,
                              itemCount: tlb.entries.length,
                              itemBuilder: (context, index) {
                                return SizedBox(
                                  height: 44,
                                  child: _TLBEntryRow(
                                    entry: tlb.entries[index],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Column header
// ============================================================

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 34,
      child: Row(
        children: [
          _HeaderCell(label: 'VPN', flex: 2),
          _HeaderCell(label: 'PPN', flex: 2),
          _HeaderCell(label: 'V', flex: 1),
          _HeaderCell(label: 'LAST', flex: 2),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TLB entry
// ============================================================

class _TLBEntryRow extends StatelessWidget {
  const _TLBEntryRow({required this.entry});

  final TLBEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          _ValueCell(value: entry.valid ? 'V${entry.vpn}' : '--', flex: 2),

          _ValueCell(value: entry.valid ? 'P${entry.ppn}' : '--', flex: 2),

          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                width: 26,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: entry.valid
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                child: Text(
                  entry.valid ? '1' : '0',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 12,
                    color: entry.valid
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          _ValueCell(
            value: '${entry.lastAccess}',
            flex: 2,
            muted: !entry.valid,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Value cell
// ============================================================

class _ValueCell extends StatelessWidget {
  const _ValueCell({
    required this.value,
    required this.flex,
    this.muted = false,
  });

  final String value;
  final int flex;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 14,
            color: muted
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
