import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/foundation/access.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';

class AccessSequenceWidget extends StatefulWidget {
  const AccessSequenceWidget({super.key});

  @override
  State<AccessSequenceWidget> createState() => _AccessSequenceWidgetState();
}

class _AccessSequenceWidgetState extends State<AccessSequenceWidget> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _editorController = TextEditingController();

  AccessSequence get accessSequence => AccessSequence.singleton;
  Runtime get runtime => Runtime.singleton;
  Configuration get configuration => Configuration.singleton;

  int get _addressBits => configuration.vpnBits + configuration.pageOffsetBits;

  int get _maxAddress => (1 << _addressBits) - 1;

  bool _isDirty = false;
  bool _updatingController = false;
  String? _error;
  late String _savedText;

  @override
  void initState() {
    super.initState();

    _savedText = _serializeSequence(accessSequence.sequence);
    _editorController.text = _savedText;

    _editorController.addListener(_handleEditorChanged);
    accessSequence.addListener(_handleSequenceChanged);
  }

  @override
  void dispose() {
    _editorController.removeListener(_handleEditorChanged);
    accessSequence.removeListener(_handleSequenceChanged);

    _scrollController.dispose();
    _editorController.dispose();

    super.dispose();
  }

  // ================================================================
  // ADDRESS FORMATTING AND PARSING
  // ================================================================

  String _formatAddress(int address) {
    return '0x${address.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  int? _parseAddress(String input) {
    final value = input.trim();

    if (value.isEmpty) return null;

    try {
      if (value.toLowerCase().startsWith('0x')) {
        if (value.length <= 2) return null;
        return int.parse(value.substring(2), radix: 16);
      }

      return int.parse(value);
    } on FormatException {
      return null;
    }
  }

  String _serializeSequence(List<Access> sequence) {
    return sequence
        .map((access) {
          final type = access.type == AccessType.load ? 'L' : 'S';
          return '$type ${_formatAddress(access.address)}';
        })
        .join('\n');
  }

  // ================================================================
  // EDITOR STATE AND SYNCHRONIZATION
  // ================================================================

  void _setEditorText(String text) {
    _updatingController = true;

    _editorController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    _updatingController = false;
  }

  void _handleEditorChanged() {
    if (_updatingController || !mounted) return;

    final dirty = _editorController.text != _savedText;

    setState(() {
      _isDirty = dirty;
      _error = null;
    });
  }

  void _handleSequenceChanged() {
    if (!mounted || _isDirty) return;

    final latestText = _serializeSequence(accessSequence.sequence);

    if (latestText == _savedText) return;

    _savedText = latestText;
    _setEditorText(latestText);

    setState(() {
      _isDirty = false;
      _error = null;
    });
  }

  // ================================================================
  // SAVE AND VALIDATION
  // ================================================================

  void _saveEditing() {
    if (!_isDirty) return;

    final newSequence = <Access>[];
    final lines = _editorController.text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Ignore blank lines.
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));

      if (parts.length != 2) {
        setState(() {
          _error = 'Line ${i + 1}: Use "L 0x0040" or "S 64".';
        });
        return;
      }

      final typeText = parts[0].toUpperCase();

      final AccessType type;

      if (typeText == 'L') {
        type = AccessType.load;
      } else if (typeText == 'S') {
        type = AccessType.store;
      } else {
        setState(() {
          _error = 'Line ${i + 1}: Access type must be L or S.';
        });
        return;
      }

      final address = _parseAddress(parts[1]);

      if (address == null || address < 0) {
        setState(() {
          _error = 'Line ${i + 1}: Enter a valid non-negative address.';
        });
        return;
      }

      if (address > _maxAddress) {
        setState(() {
          _error =
              'Line ${i + 1}: Address exceeds the configured '
              'virtual address space. Maximum: '
              '${_formatAddress(_maxAddress)}.';
        });
        return;
      }

      newSequence.add(Access(type: type, address: address));
    }

    // Normalize the editor contents and update the saved baseline first.
    final normalizedText = _serializeSequence(newSequence);

    _savedText = normalizedText;
    _setEditorText(normalizedText);

    setState(() {
      _isDirty = false;
      _error = null;
    });

    // Apply the sequence only after every line passes validation.
    accessSequence.setSequence(newSequence);
    runtime.reset();
  }

  // ================================================================
  // SCROLLING
  // ================================================================

  void scrollToPointer(int pointer) {
    final sequence = accessSequence.sequence;

    if (sequence.isEmpty ||
        pointer < 0 ||
        pointer >= sequence.length ||
        !_scrollController.hasClients) {
      return;
    }

    const itemHeight = 62.0;

    _scrollController.animateTo(
      (pointer * itemHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 300;

          return ListenableBuilder(
            listenable: Listenable.merge([accessSequence, runtime]),
            builder: (context, child) {
              final count = _editorController.text
                  .split('\n')
                  .where((line) => line.trim().isNotEmpty)
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, count, compact: compact),

                  const Divider(height: 1),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontFamily: 'Nunito',
                          fontSize: 11,
                        ),
                      ),
                    ),

                  Expanded(child: _buildEditorList(compact: compact)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ================================================================
  // HEADER
  // ================================================================

  Widget _buildHeader(
    BuildContext context,
    int count, {
    required bool compact,
  }) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
        child: Row(
          children: [
            Icon(
              Icons.format_list_numbered_rounded,
              size: 20,
              color: colors.primary,
            ),

            SizedBox(width: compact ? 4 : 8),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Access Sequence',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: compact ? 13 : 16,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            _headerButton(
              context,
              icon: Icons.save_rounded,
              tooltip: _isDirty
                  ? 'Save changes to the access sequence'
                  : 'No unsaved changes',
              onPressed: _saveEditing,
              enabled: _isDirty,
              color: _isDirty
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool enabled = true,
    Color? color,
  }) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 18, color: color),
    );
  }

  // ================================================================
  // TEXT EDITOR
  // ================================================================

  Widget _buildEditorList({required bool compact}) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.all(compact ? 6 : 10),
      child: TextField(
        controller: _editorController,
        expands: true,
        minLines: null,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontFamily: 'Roboto-Mono',
          fontSize: compact ? 11 : 13,
          height: 1.65,
          color: colors.onSurface,
        ),
        decoration: InputDecoration(
          hintText:
              'Enter one access per line:\n\n'
              'L 0x0040\n'
              'S 0x0080\n'
              'L 128',
          hintStyle: TextStyle(
            fontFamily: 'Roboto-Mono',
            fontSize: compact ? 11 : 13,
            height: 1.65,
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          filled: true,
          fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.25),
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// ACCESS ITEM
// ==================================================================

class _AccessItem extends StatelessWidget {
  final Access access;
  final int index;
  final bool isActive;
  final bool compact;

  const _AccessItem({
    required this.access,
    required this.index,
    required this.isActive,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final foreground = isActive ? colors.onPrimaryContainer : colors.onSurface;

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 10),
      decoration: BoxDecoration(
        color: isActive ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 20 : 32,
            child: Text(
              '${index + 1}',
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: compact ? 12 : 16,
                color: foreground.withValues(alpha: 0.6),
              ),
            ),
          ),

          _AccessTypeBadge(type: access.type, compact: compact),

          SizedBox(width: compact ? 5 : 12),

          Expanded(
            child: Text(
              '0x${access.address.toRadixString(16).toUpperCase().padLeft(4, '0')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: compact ? 13 : 18,
                color: foreground,
              ),
            ),
          ),

          if (isActive)
            Icon(
              Icons.play_arrow_rounded,
              size: compact ? 16 : 22,
              color: colors.primary,
            ),
        ],
      ),
    );
  }
}

// ==================================================================
// ACCESS TYPE BADGE
// ==================================================================

class _AccessTypeBadge extends StatelessWidget {
  final AccessType type;
  final bool compact;

  const _AccessTypeBadge({required this.type, required this.compact});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLoad = type == AccessType.load;

    return Container(
      width: compact ? 42 : 58,
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 6, vertical: 5),
      decoration: BoxDecoration(
        color: isLoad ? colors.secondaryContainer : colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        isLoad ? 'LOAD' : 'STORE',
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: compact ? 8 : 10,
          fontWeight: FontWeight.w800,
          color: isLoad ? colors.secondary : colors.onTertiaryContainer,
        ),
      ),
    );
  }
}
