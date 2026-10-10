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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // Component header
            // --------------------------------------------------
            Row(
              children: [
                Icon(
                  Icons.table_rows_outlined,
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
            // Column headers
            // --------------------------------------------------
            const _HeaderRow(),

            const SizedBox(height: 6),

            // --------------------------------------------------
            // Individual TLB entries
            // --------------------------------------------------
            Expanded(
              child: ListenableBuilder(
                listenable: Runtime.singleton,
                builder: (context, _) {
                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                      itemCount: tlb.entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 5),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          height: 38,
                          child: _TLBEntryRow(entry: tlb.entries[index]),
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
    final theme = Theme.of(context);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Row(
        children: [
          _HeaderCell(label: 'V', flex: 1),
          _HeaderCell(label: 'VPN', flex: 2),
          _HeaderCell(label: 'PPN', flex: 2),
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
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TLB entry container
// ============================================================

class _TLBEntryRow extends StatelessWidget {
  const _TLBEntryRow({required this.entry});

  final TLBEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runtime = Runtime.singleton;
    final isEntryAccessed =
        entry.valid &&
        (runtime.getVPN == entry.vpn) &&
        (runtime.connectVAtoTLB || runtime.connectPageTableToTLB);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: isEntryAccessed
            ? theme.colorScheme.primary.withValues(alpha: 0.06)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEntryAccessed
              ? colors.primary.withValues(alpha: 0.35)
              : colors.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          // Valid bit
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                width: 24,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entry.valid
                      ? theme.colorScheme.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
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
                    fontWeight: FontWeight.w600,
                    color: entry.valid
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          // VPN is stored as part of the TLB entry.
          _ValueCell(
            value: entry.valid ? '${entry.vpn}' : '--',
            flex: 2,
            muted: !entry.valid,
          ),

          _ValueCell(
            value: entry.valid ? '${entry.ppn}' : '--',
            flex: 2,
            muted: !entry.valid,
          ),

          _ValueCell(
            value: entry.valid ? '${entry.lastAccess}' : '--',
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
            fontWeight: FontWeight.w500,
            color: muted
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
