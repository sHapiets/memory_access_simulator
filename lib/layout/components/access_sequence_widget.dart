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

class _AccessDraft {
  AccessType type;
  final TextEditingController addressController;

  _AccessDraft({required this.type, required String address})
    : addressController = TextEditingController(text: address);

  void dispose() => addressController.dispose();
}

class _AccessSequenceWidgetState extends State<AccessSequenceWidget> {
  final ScrollController _scrollController = ScrollController();

  AccessSequence get accessSequence => AccessSequence.singleton;
  Runtime get runtime => Runtime.singleton;
  Configuration get configuration => Configuration.singleton;

  int get _addressBits => configuration.vpnBits + configuration.pageOffsetBits;

  int get _maxAddress => (1 << _addressBits) - 1;

  bool _isEditing = false;
  String? _error;
  final List<_AccessDraft> _drafts = [];

  @override
  void dispose() {
    _scrollController.dispose();
    _disposeDrafts();
    super.dispose();
  }

  void _disposeDrafts() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _drafts.clear();
  }

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

  void _startEditing() {
    _disposeDrafts();

    _drafts.addAll(
      accessSequence.sequence.map(
        (access) => _AccessDraft(
          type: access.type,
          address: _formatAddress(access.address),
        ),
      ),
    );

    setState(() {
      _isEditing = true;
      _error = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _disposeDrafts();
      _isEditing = false;
      _error = null;
    });
  }

  void _addAccess() {
    setState(() {
      _drafts.add(_AccessDraft(type: AccessType.load, address: '0x0000'));
      _error = null;
    });
  }

  void _removeAccess(int index) {
    setState(() {
      _drafts.removeAt(index).dispose();
      _error = null;
    });
  }

  void _saveEditing() {
    final newSequence = <Access>[];

    for (var i = 0; i < _drafts.length; i++) {
      final draft = _drafts[i];
      final address = _parseAddress(draft.addressController.text);

      if (address == null || address < 0) {
        setState(() {
          _error = 'Access ${i + 1}: Enter a valid NON-NEGATIVE address...';
        });
        return;
      }

      if (address > _maxAddress) {
        setState(() {
          _error =
              'ACCESS ${i + 1}: Address exceeds the configured virtual address space... '
              '(maximum: 0x${_maxAddress.toRadixString(16).toUpperCase().padLeft(4, '0')}).';
        });
        return;
      }

      newSequence.add(Access(type: draft.type, address: address));
    }

    accessSequence.setSequence(newSequence);

    setState(() {
      _disposeDrafts();
      _isEditing = false;
      _error = null;
    });
  }

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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(
                    context,
                    _isEditing ? _drafts.length : sequence.length,
                    compact: compact,
                  ),
                  const Divider(height: 1),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
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

  Widget _buildHeader(
    BuildContext context,
    int count, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                'Access Sequence',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),

            if (_isEditing) ...[
              _headerButton(
                context,
                icon: Icons.add_rounded,
                tooltip: 'Add Access',
                onPressed: _addAccess,
              ),
              SizedBox(width: 4),
              _headerButton(
                context,
                icon: Icons.close_rounded,
                tooltip: 'Cancel Editing',
                onPressed: _cancelEditing,
              ),
              SizedBox(width: 4),
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
                tooltip: 'Edit',
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

  Widget _buildEditorList({required bool compact}) {
    if (_drafts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No accesses yet...',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontFamily: 'Nunito'),
            ),
            SizedBox(height: 5),
            Text(
              'Click the "+" button above to start',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontFamily: 'Nunito'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: compact ? 4 : 8),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];

        return _EditableAccessItem(
          key: ObjectKey(draft),
          index: index,
          draft: draft,
          compact: compact,
          onChanged: () {
            setState(() {
              _error = null;
            });
          },
          onRemove: () => _removeAccess(index),
        );
      },
    );
  }

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

class _EditableAccessItem extends StatelessWidget {
  final int index;
  final _AccessDraft draft;
  final bool compact;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _EditableAccessItem({
    super.key,
    required this.index,
    required this.draft,
    required this.compact,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 18 : 26,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: compact ? 11 : 14,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Access type selector.
          DropdownButtonHideUnderline(
            child: DropdownButton<AccessType>(
              value: draft.type,
              isDense: true,
              iconSize: compact ? 16 : 18,
              borderRadius: BorderRadius.circular(8),
              items: [
                DropdownMenuItem(
                  value: AccessType.load,
                  child: Text(
                    'LOAD',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: compact ? 9 : 11,
                      fontWeight: FontWeight.w800,
                      color: colors.secondary,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: AccessType.store,
                  child: Text(
                    'STORE',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: compact ? 9 : 11,
                      fontWeight: FontWeight.w800,
                      color: colors.tertiary,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                draft.type = value;
                onChanged();
              },
            ),
          ),

          const SizedBox(width: 4),

          // Address editor. Accepts decimal or 0x-prefixed hexadecimal.
          Expanded(
            child: TextField(
              controller: draft.addressController,
              onChanged: (_) => onChanged(),
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: compact ? 12 : 15,
                color: colors.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Address',
                hintStyle: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: compact ? 10 : 12,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: compact ? 5 : 8,
                  vertical: 9,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),

          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove access',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: compact ? 17 : 20,
              color: colors.error,
            ),
          ),
        ],
      ),
    );
  }
}
