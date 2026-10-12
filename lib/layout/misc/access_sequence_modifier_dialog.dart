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

  late final TextEditingController sequenceController;

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
    sequenceController.removeListener(_parseSequence);
    sequenceController.dispose();
    super.dispose();
  }

  // ========================================================================
  // Sequence formatting
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

  String _formatAddress(int address) {
    return address.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  // ========================================================================
  // Address limits
  // ========================================================================

  int get _addressBits => configuration.vpnBits + configuration.pageOffsetBits;

  int get _maxAddress => (1 << _addressBits) - 1;

  // ========================================================================
  // Parsing and validation
  // ========================================================================

  void _parseSequence() {
    final lines = sequenceController.text.split('\n');
    final results = <_ParsedAccess>[];

    for (int i = 0; i < lines.length; i++) {
      results.add(_parseLine(lines[i], i));
    }

    if (!mounted) return;

    setState(() {
      parsedAccesses = results;
    });
  }

  _ParsedAccess _parseLine(String line, int index) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      return _ParsedAccess.empty(index);
    }

    final parts = trimmed.split(RegExp(r'\s+'));

    if (parts.length != 2) {
      return _ParsedAccess.invalid(
        index,
        'Expected an access type followed by an address.',
      );
    }

    final typeCode = parts[0].toUpperCase();

    final AccessType type;

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

    final addressString = parts[1];
    int? address;

    try {
      if (addressString.toLowerCase().startsWith('0x')) {
        final hex = addressString.substring(2);

        if (hex.isEmpty) {
          throw const FormatException();
        }

        address = int.parse(hex, radix: 16);
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

  bool get _hasErrors => parsedAccesses.any((entry) => entry.error != null);

  int get _validAccessCount =>
      parsedAccesses.where((entry) => entry.access != null).length;

  int get _errorCount =>
      parsedAccesses.where((entry) => entry.error != null).length;

  // ========================================================================
  // Save
  // ========================================================================

  void saveSequence() {
    if (_hasErrors) return;

    final sequence = parsedAccesses
        .where((entry) => entry.access != null)
        .map((entry) => entry.access!)
        .toList();

    accessSequence.setSequence(sequence);
    Runtime.singleton.reset();

    Navigator.of(context).pop();
  }

  // ========================================================================
  // Editor styling — matches AccessSequenceWidget edit mode
  // ========================================================================

  TextStyle _editorTextStyle(ThemeData theme) {
    return TextStyle(
      fontFamily: 'Roboto-Mono',
      fontSize: 13,
      height: 1.65,
      fontWeight: FontWeight.w400,
      color: theme.colorScheme.onSurface,
    );
  }

  InputDecoration _editorDecoration(ThemeData theme) {
    final borderColor = theme.colorScheme.outlineVariant;

    return InputDecoration(
      hintText: 'L 0x0040\nS 0x00A4\nL 0x001C',
      hintStyle: _editorTextStyle(
        theme,
      ).copyWith(color: theme.colorScheme.onSurface.withOpacity(0.35)),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.25),
      contentPadding: const EdgeInsets.all(12),
      isCollapsed: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: _hasErrors
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  // ========================================================================
  // Header
  // ========================================================================

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.edit_note_rounded,
            size: 23,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Access Sequence',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'L = Load   ·   S = Store',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),

        // Cancel editing
        IconButton(
          tooltip: 'Cancel',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),

        // Save changes
        IconButton(
          tooltip: 'Save sequence',
          visualDensity: VisualDensity.compact,
          onPressed: _hasErrors ? null : saveSequence,
          style: IconButton.styleFrom(
            backgroundColor: _hasErrors
                ? null
                : theme.colorScheme.primary.withValues(alpha: 0.10),
            foregroundColor: theme.colorScheme.primary,
            disabledForegroundColor: theme.colorScheme.onSurface.withOpacity(
              0.3,
            ),
          ),
          icon: const Icon(Icons.check_rounded),
        ),
      ],
    );
  }

  // ========================================================================
  // Validation status
  // ========================================================================

  Widget _buildStatus(ThemeData theme) {
    final Color statusColor = _hasErrors
        ? theme.colorScheme.error
        : Colors.green.shade600;

    return Row(
      children: [
        Icon(
          _hasErrors
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          size: 16,
          color: statusColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _hasErrors
                ? '$_errorCount Invalid '
                      '${_errorCount == 1 ? 'Entry' : 'Entries'}'
                : 'Valid Sequence!',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
        if (_hasErrors)
          Text(
            'Fix errors to save',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          )
        else
          Text(
            'Enter one access per line',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
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

    return Dialog(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.98),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 520,
        height: 510,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme),

              const SizedBox(height: 12),

              // Subtle divider, similar to the widget's edit-mode layout.
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.6),
              ),

              const SizedBox(height: 12),

              // Main editor — gets almost all available space.
              Expanded(
                child: TextField(
                  controller: sequenceController,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: _editorTextStyle(theme),
                  decoration: _editorDecoration(theme),
                ),
              ),

              const SizedBox(height: 10),

              _buildStatus(theme),
            ],
          ),
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
