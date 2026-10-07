import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/configuration.dart';
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

  late TextEditingController sequenceController;

  List<_ParsedAccess> parsedAccesses = [];

  @override
  void initState() {
    super.initState();

    sequenceController = TextEditingController(text: _sequenceToText());

    sequenceController.addListener(_parseSequence);

    _parseSequence();
  }

  @override
  void dispose() {
    sequenceController.dispose();
    super.dispose();
  }

  // ========================================================================
  // Existing sequence -> text
  // ========================================================================

  String _sequenceToText() {
    return accessSequence.sequence
        .map((access) {
          final type = access.type == AccessType.load ? 'L' : 'S';

          final address = access.address
              .toRadixString(16)
              .toUpperCase()
              .padLeft(4, '0');

          return '$type 0x$address';
        })
        .join('\n');
  }

  // ========================================================================
  // Address limits
  // ========================================================================

  int get _addressBits {
    return configuration.vpnBits + configuration.pageOffsetBits;
  }

  int get _maxAddress {
    return (1 << _addressBits) - 1;
  }

  // ========================================================================
  // Parsing
  // ========================================================================

  void _parseSequence() {
    final lines = sequenceController.text.split('\n');

    final results = <_ParsedAccess>[];

    for (int i = 0; i < lines.length; i++) {
      results.add(_parseLine(lines[i], i));
    }

    setState(() {
      parsedAccesses = results;
    });
  }

  _ParsedAccess _parseLine(String line, int index) {
    final trimmed = line.trim();

    // Empty lines are allowed.
    if (trimmed.isEmpty) {
      return _ParsedAccess.empty(index);
    }

    final parts = trimmed.split(RegExp(r'\s+'));

    // We expect:
    //
    // L 0x0040
    //
    // or
    //
    // S 64

    if (parts.length != 2) {
      return _ParsedAccess.invalid(
        index,
        'Expected an access type followed by an address.',
      );
    }

    // ------------------------------------------------------------
    // Access type
    // ------------------------------------------------------------

    final typeCode = parts[0].toUpperCase();

    AccessType? type;

    switch (typeCode) {
      case 'L':
        type = AccessType.load;
        break;

      case 'S':
        type = AccessType.store;
        break;

      default:
        return _ParsedAccess.invalid(
          index,
          'Invalid access type "$typeCode". Use L or S.',
        );
    }

    // ------------------------------------------------------------
    // Address
    // ------------------------------------------------------------

    final addressString = parts[1];

    int? address;

    try {
      if (addressString.toLowerCase().startsWith('0x')) {
        address = int.parse(addressString.substring(2), radix: 16);
      } else {
        address = int.parse(addressString);
      }
    } catch (_) {
      return _ParsedAccess.invalid(index, 'Invalid address "$addressString".');
    }

    if (address < 0) {
      return _ParsedAccess.invalid(index, 'Address cannot be negative.');
    }

    if (address > _maxAddress) {
      return _ParsedAccess.invalid(
        index,
        'Address exceeds the configured address space '
        '(maximum: 0x${_formatAddress(_maxAddress)}).',
      );
    }

    return _ParsedAccess.valid(index, Access(type: type, address: address));
  }

  String _formatAddress(int address) {
    return address.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  // ========================================================================
  // Validation
  // ========================================================================

  bool get _hasErrors {
    return parsedAccesses.any((entry) => entry.error != null);
  }

  int get _validAccessCount {
    return parsedAccesses.where((entry) => entry.access != null).length;
  }

  // ========================================================================
  // Save
  // ========================================================================

  void saveSequence() {
    if (_hasErrors) {
      return;
    }

    final sequence = parsedAccesses
        .where((entry) => entry.access != null)
        .map((entry) => entry.access!)
        .toList();

    accessSequence.sequence = sequence;
    accessSequence.pointer = 0;

    Navigator.pop(context);
  }

  // ========================================================================
  // UI helpers
  // ========================================================================

  Widget _buildFormatHelp(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Access Format',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Enter one access per line:',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'L 0x0040\n'
            'S 0x00A4\n'
            'L 64',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 14,
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'L = Load    S = Store',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(ThemeData theme) {
    if (_hasErrors) {
      final errorCount = parsedAccesses
          .where((entry) => entry.error != null)
          .length;

      return Row(
        children: [
          Icon(Icons.error_outline, size: 17, color: theme.colorScheme.error),
          const SizedBox(width: 7),
          Text(
            '$errorCount invalid '
            '${errorCount == 1 ? 'entry' : 'entries'}',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 17,
          color: Colors.green.shade600,
        ),
        const SizedBox(width: 7),
        Text(
          '$_validAccessCount '
          '${_validAccessCount == 1 ? 'access' : 'accesses'}',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.green.shade600,
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // Build
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = !_hasErrors;

    return Dialog(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isValid
              ? theme.colorScheme.primary.withOpacity(0.45)
              : theme.colorScheme.error.withOpacity(0.5),
        ),
      ),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==============================================================
            // Header
            // ==============================================================
            Row(
              children: [
                Icon(
                  Icons.format_list_numbered,
                  color: isValid
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  size: 24,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Access Sequence',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ==============================================================
            // Format help
            // ==============================================================
            _buildFormatHelp(theme),

            const SizedBox(height: 16),

            // ==============================================================
            // Text editor
            // ==============================================================
            Expanded(
              child: TextField(
                controller: sequenceController,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 15,
                  height: 1.5,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText:
                      'L 0x0040\n'
                      'S 0x00A4\n'
                      'L 0x001C',
                  hintStyle: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 15,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.25),

                  contentPadding: const EdgeInsets.all(14),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _hasErrors
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ==============================================================
            // Status
            // ==============================================================
            _buildStatus(theme),

            const SizedBox(height: 16),

            // ==============================================================
            // Buttons
            // ==============================================================
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isValid ? saveSequence : null,
                    icon: const Icon(Icons.save),
                    label: const Text(
                      'Save Sequence',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      disabledBackgroundColor: theme.colorScheme.errorContainer
                          .withOpacity(0.5),
                      disabledForegroundColor: theme
                          .colorScheme
                          .onErrorContainer
                          .withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Parsed Access
// ============================================================================

class _ParsedAccess {
  final int lineNumber;
  final Access? access;
  final String? error;

  const _ParsedAccess({required this.lineNumber, this.access, this.error});

  factory _ParsedAccess.valid(int lineNumber, Access access) {
    return _ParsedAccess(lineNumber: lineNumber, access: access);
  }

  factory _ParsedAccess.invalid(int lineNumber, String error) {
    return _ParsedAccess(lineNumber: lineNumber, error: error);
  }

  factory _ParsedAccess.empty(int lineNumber) {
    return _ParsedAccess(lineNumber: lineNumber);
  }
}
