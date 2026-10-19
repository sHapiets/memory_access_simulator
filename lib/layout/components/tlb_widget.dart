import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/tlb.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/foundation/tlb_entry.dart';
import 'package:flutter/services.dart';

class TLBWidget extends StatefulWidget {
  const TLBWidget({super.key, this.isEditMode = false});

  final bool isEditMode;

  static const double width = 500;
  static const double height = 400;

  @override
  State<TLBWidget> createState() => _TLBWidgetState();
}

class _TLBWidgetState extends State<TLBWidget> {
  final ScrollController _scrollController = ScrollController();

  // Each entry has controllers for: valid, VPN, PPN, last access.
  List<List<TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }

    _controllers = TLB.singleton.entries.map((entry) {
      return [
        TextEditingController(text: entry.valid ? '1' : '0'),
        TextEditingController(text: '${entry.vpn}'),
        TextEditingController(text: '${entry.ppn}'),
        TextEditingController(text: '${entry.lastAccess}'),
      ];
    }).toList();
  }

  @override
  void didUpdateWidget(covariant TLBWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Refresh the form whenever edit mode is entered.
    if (!oldWidget.isEditMode && widget.isEditMode) {
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }

    _scrollController.dispose();
    super.dispose();
  }

  void _saveEntries() {
    final tlb = TLB.singleton;
    final config = Configuration.singleton;

    final vpnMax = config.pageTableSizeEntries - 1;
    final ppnMax = config.dynamicSizePages - 1;

    // Validate every row before modifying the TLB.
    for (int i = 0; i < tlb.entries.length; i++) {
      final values = _controllers[i];

      final valid = int.tryParse(values[0].text);
      final vpn = int.tryParse(values[1].text);
      final ppn = int.tryParse(values[2].text);
      final lastAccess = int.tryParse(values[3].text);

      String? error;

      if (valid == null || (valid != 0 && valid != 1)) {
        error = 'Valid bit must be 0 or 1.';
      } else if (vpn == null || vpn < 0 || vpn > vpnMax) {
        error = 'VPN must be between 0 and $vpnMax.';
      } else if (ppn == null || ppn < 0 || ppn > ppnMax) {
        error = 'PPN must be between 0 and $ppnMax.';
      } else if (lastAccess == null || lastAccess < 0) {
        error = 'Last access must be a non-negative integer.';
      }

      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Entry ${i + 1}: $error')));
        return;
      }
    }

    // All entries are valid. Commit changes to the singleton.
    for (int i = 0; i < tlb.entries.length; i++) {
      final values = _controllers[i];
      final entry = tlb.entries[i];

      entry.valid = int.parse(values[0].text) == 1;
      entry.vpn = int.parse(values[1].text);
      entry.ppn = int.parse(values[2].text);
      entry.lastAccess = int.parse(values[3].text);
    }

    // Notify widgets listening to Runtime to rebuild.
    Runtime.singleton.notifyListeners();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('TLB entries saved.')));
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
            // Component header and Save button.
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
                const Spacer(),
                if (widget.isEditMode)
                  FilledButton.icon(
                    onPressed: _saveEntries,
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Save'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            _HeaderRow(isEditMode: widget.isEditMode),

            const SizedBox(height: 6),

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
                          child: _TLBEntryRow(
                            entry: tlb.entries[index],
                            isEditMode: widget.isEditMode,
                            controllers: _controllers[index],
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
    );
  }
}

// ============================================================
// Column header
// ============================================================

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.isEditMode});

  final bool isEditMode;

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
            fontSize: 15,
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
  const _TLBEntryRow({
    required this.entry,
    required this.isEditMode,
    required this.controllers,
  });

  final TLBEntry entry;
  final bool isEditMode;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runtime = Runtime.singleton;
    final colors = theme.colorScheme;

    final isEntryAccessed =
        entry.valid &&
        runtime.getVPN == entry.vpn &&
        (runtime.connectVAtoTLB.active || runtime.connectPageTableToTLB.active);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: isEntryAccessed
            ? colors.primary.withValues(alpha: 0.06)
            : colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEntryAccessed
              ? colors.primary.withValues(alpha: 0.35)
              : colors.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          if (isEditMode)
            _EditableCell(
              controller: controllers[0],
              flex: 1,
              minValue: 0,
              maxValue: 1,
            )
          else
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  width: 24,
                  height: 21,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.valid
                        ? colors.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: entry.valid ? colors.primary : colors.outline,
                    ),
                  ),
                  child: Text(
                    entry.valid ? '1' : '0',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entry.valid
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

          if (isEditMode)
            _EditableCell(
              controller: controllers[1],
              flex: 2,
              minValue: 0,
              maxValue: Configuration.singleton.pageTableSizeEntries - 1,
            )
          else
            _ValueCell(
              value: entry.valid ? '${entry.vpn}' : '--',
              flex: 2,
              muted: !entry.valid,
            ),

          if (isEditMode)
            _EditableCell(
              controller: controllers[2],
              flex: 2,
              minValue: 0,
              maxValue: Configuration.singleton.dynamicSizePages - 1,
            )
          else
            _ValueCell(
              value: entry.valid ? '${entry.ppn}' : '--',
              flex: 2,
              muted: !entry.valid,
            ),

          if (isEditMode)
            _EditableCell(controller: controllers[3], flex: 2, minValue: 0)
          else
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
            fontSize: 20,
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

class _EditableCell extends StatelessWidget {
  const _EditableCell({
    required this.controller,
    required this.flex,
    required this.minValue,
    this.maxValue,
  });

  final TextEditingController controller;
  final int flex;
  final int minValue;
  final int? maxValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 5,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
