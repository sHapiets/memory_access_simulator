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

  bool _isEditing = false;
  String? _error;

  @override
  void dispose() {
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

  // ================================================================
  // EDITING
  // ================================================================

  void _startEditing() {
    final text = accessSequence.sequence
        .map((access) {
          final type = access.type == AccessType.load ? 'L' : 'S';
          return '$type ${_formatAddress(access.address)}';
        })
        .join('\n');

    setState(() {
      _editorController.text = text;
      _isEditing = true;
      _error = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _error = null;
      _editorController.clear();
    });
  }

  void _saveEditing() {
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

    // Apply the sequence only after every line passes validation.
    accessSequence.setSequence(newSequence);
    runtime.reset();

    setState(() {
      _isEditing = false;
      _error = null;
      _editorController.clear();
    });
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
              final sequence = accessSequence.sequence;

              final count = _isEditing
                  ? _editorController.text
                        .split('\n')
                        .where((line) => line.trim().isNotEmpty)
                        .length
                  : sequence.length;

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

                  Expanded(
                    child: _isEditing
                        ? _buildEditorList(compact: compact)
                        : _buildSequenceList(
                            sequence,
                            accessSequence.pointer,
                            compact: compact,
                          ),
                  ),
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
              child: Text(
                _isEditing ? 'Edit Sequence' : 'Access Sequence',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: compact ? 13 : 16,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),

            if (_isEditing) ...[
              _headerButton(
                context,
                icon: Icons.close_rounded,
                tooltip: 'Cancel Editing',
                onPressed: _cancelEditing,
              ),
              const SizedBox(width: 4),
              _headerButton(
                context,
                icon: Icons.check_rounded,
                tooltip: 'Save Changes',
                onPressed: _saveEditing,
                color: colors.primary,
              ),
            ] else
              _headerButton(
                context,
                icon: Icons.edit_rounded,
                tooltip: 'Edit Sequence',
                onPressed: _startEditing,
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
    Color? color,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 18, color: color),
    );
  }

  // ================================================================
  // NORMAL ACCESS SEQUENCE LIST
  // ================================================================

  Widget _buildSequenceList(
    List<Access> sequence,
    int pointer, {
    required bool compact,
  }) {
    if (sequence.isEmpty) {
      return _buildEmptyState(context, 'No accesses');
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: compact ? 4 : 8),
      itemCount: sequence.length,
      itemBuilder: (context, index) {
        return _AccessItem(
          access: sequence[index],
          index: index,
          isActive: index == pointer,
          compact: compact,
        );
      },
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
        onChanged: (_) {
          setState(() {
            _error = null;
          });
        },
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

  // ================================================================
  // EMPTY STATE
  // ================================================================

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontFamily: 'Nunito'),
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
