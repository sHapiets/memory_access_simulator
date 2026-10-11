import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/foundation/access.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';

class AccessSequenceModifierDialog extends StatefulWidget {
  const AccessSequenceModifierDialog({super.key});

  @override
  State<AccessSequenceModifierDialog> createState() =>
      _AccessSequenceModifierDialogState();
}

class _AccessSequenceModifierDialogState
    extends State<AccessSequenceModifierDialog> {
  final configuration = Configuration.singleton;
  final accessSequence = AccessSequence.singleton;

  final List<_AccessDraft> _drafts = [];

  @override
  void initState() {
    super.initState();

    for (final access in accessSequence.sequence) {
      _drafts.add(
        _AccessDraft(
          type: access.type,
          addressController: TextEditingController(
            text: _formatAddress(access.address),
          ),
        ),
      );
    }

    if (_drafts.isEmpty) {
      _drafts.add(_AccessDraft());
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // ADDRESS LIMITS
  // ============================================================

  int get _addressBits => configuration.vpnBits + configuration.pageOffsetBits;

  int get _maxAddress => (1 << _addressBits) - 1;

  String _formatAddress(int address) {
    return '0x${address.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  int? _parseAddress(String input) {
    final value = input.trim();

    if (value.isEmpty) return null;

    try {
      if (value.toLowerCase().startsWith('0x')) {
        final digits = value.substring(2);
        if (digits.isEmpty) return null;
        return int.parse(digits, radix: 16);
      }

      return int.parse(value);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _isBlank(_AccessDraft draft) {
    return draft.addressController.text.trim().isEmpty;
  }

  String? _errorFor(_AccessDraft draft) {
    final input = draft.addressController.text.trim();

    // Empty rows are ignored, allowing the user to add a row
    // before entering its address.
    if (input.isEmpty) return null;

    final address = _parseAddress(input);

    if (address == null) {
      return 'Enter a valid decimal or hexadecimal address.';
    }

    if (address < 0) {
      return 'Address cannot be negative.';
    }

    if (address > _maxAddress) {
      return 'Address exceeds the configured address space '
          '(maximum: ${_formatAddress(_maxAddress)}).';
    }

    return null;
  }

  bool get _hasErrors =>
      _drafts.any((draft) => !_isBlank(draft) && _errorFor(draft) != null);

  int get _validCount => _drafts.where((draft) {
    return !_isBlank(draft) && _errorFor(draft) == null;
  }).length;

  int get _errorCount => _drafts.where((draft) {
    return !_isBlank(draft) && _errorFor(draft) != null;
  }).length;

  // ============================================================
  // EDITING
  // ============================================================

  void _addAccess() {
    setState(() {
      _drafts.add(_AccessDraft());
    });
  }

  void _removeAccess(int index) {
    setState(() {
      final removed = _drafts.removeAt(index);
      removed.dispose();
    });
  }

  void _saveSequence() {
    if (_hasErrors) return;

    final sequence = <Access>[];

    for (final draft in _drafts) {
      if (_isBlank(draft)) continue;

      final address = _parseAddress(draft.addressController.text);

      if (address == null || address < 0 || address > _maxAddress) {
        return;
      }

      sequence.add(Access(type: draft.type, address: address));
    }

    accessSequence.setSequence(sequence);
    Runtime.singleton.reset();
    Navigator.of(context).pop();
  }

  // ============================================================
  // FORMAT HELP
  // ============================================================

  Widget _buildFormatHelp(ThemeData theme) {
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Access Format',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose LOAD or STORE for each access. '
            'Addresses can be decimal or hexadecimal.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _exampleChip(theme, '64'),
              _exampleChip(theme, '0x0040'),
              _exampleChip(theme, '0x00A4'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Maximum address: ${_formatAddress(_maxAddress)}',
            style: TextStyle(
              fontFamily: 'Roboto-Mono',
              fontSize: 11,
              color: colors.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exampleChip(ThemeData theme, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 12,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatus(ThemeData theme) {
    final colors = theme.colorScheme;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    if (_hasErrors) {
      statusColor = colors.error;
      statusIcon = Icons.error_outline_rounded;
      statusText =
          '$_errorCount invalid ${_errorCount == 1 ? 'entry' : 'entries'}';
    } else {
      statusColor = Colors.green.shade600;
      statusIcon = Icons.check_circle_outline_rounded;
      statusText =
          '$_validCount valid '
          '${_validCount == 1 ? 'access' : 'accesses'}';
    }

    return Row(
      children: [
        Icon(statusIcon, size: 18, color: statusColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            statusText,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
        ),
        Text(
          '${_drafts.length} ${_drafts.length == 1 ? 'row' : 'rows'}',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            color: colors.outline,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACCESS ROW
  // ============================================================

  Widget _buildAccessRow(BuildContext context, ThemeData theme, int index) {
    final colors = theme.colorScheme;
    final draft = _drafts[index];
    final error = _errorFor(draft);
    final hasError = error != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hasError
            ? colors.errorContainer.withValues(alpha: 0.22)
            : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? colors.error.withValues(alpha: 0.75)
              : colors.outlineVariant,
          width: hasError ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ROW NUMBER
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: hasError
                      ? colors.error.withValues(alpha: 0.1)
                      : colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hasError ? colors.error : colors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ACCESS TYPE
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<AccessType>(
                  initialValue: draft.type,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Access type',
                    prefixIcon: Icon(
                      draft.type == AccessType.load
                          ? Icons.download_rounded
                          : Icons.upload_rounded,
                      size: 19,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AccessType.load,
                      child: Text('LOAD', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: AccessType.store,
                      child: Text('STORE', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      draft.type = value;
                    });
                  },
                ),
              ),

              const SizedBox(width: 10),

              // ADDRESS
              Expanded(
                flex: 3,
                child: TextField(
                  controller: draft.addressController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 14,
                    color: colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Address',
                    hintText: '0x0040 or 64',
                    errorText: hasError ? 'Invalid' : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(
                        color: hasError ? colors.error : colors.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(
                        color: hasError ? colors.error : colors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // REMOVE
              IconButton(
                tooltip: 'Remove access',
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeAccess(index),
                icon: const Icon(Icons.close_rounded, size: 20),
                color: colors.error,
              ),
            ],
          ),

          if (hasError) ...[
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: colors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: colors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    final dialogWidth = math.min(screenSize.width - 32, 760.0);
    final dialogHeight = math.min(screenSize.height * 0.86, 720.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: EdgeInsets.all(screenSize.width < 600 ? 14 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.format_list_numbered_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Access Sequence',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildFormatHelp(theme),

              const SizedBox(height: 14),

              // LIST HEADER
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'MEMORY ACCESSES',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addAccess,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add access'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // EDITABLE ROWS
              Expanded(
                child: _drafts.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _drafts.length,
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _buildAccessRow(context, theme, index);
                        },
                      ),
              ),

              const SizedBox(height: 8),

              // STATUS
              _buildStatus(theme),

              const SizedBox(height: 14),

              // ACTIONS
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _hasErrors ? null : _saveSequence,
                    icon: const Icon(Icons.check_rounded, size: 19),
                    label: const Text(
                      'Save Sequence',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ACCESS DRAFT
// ============================================================================

class _AccessDraft {
  AccessType type;
  final TextEditingController addressController;

  _AccessDraft({
    this.type = AccessType.load,
    TextEditingController? addressController,
  }) : addressController = addressController ?? TextEditingController();

  void dispose() {
    addressController.dispose();
  }
}
