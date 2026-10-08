import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
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

  AccessSequence get accessSequence => AccessSequence.singleton;
  Runtime get runtime => Runtime.singleton;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToPointer(int pointer) {
    final sequence = accessSequence.sequence;

    if (sequence.isEmpty) {
      return;
    }

    if (pointer < 0 || pointer >= sequence.length) {
      return;
    }

    const itemHeight = 62.0;

    final targetOffset = pointer * itemHeight;

    if (!_scrollController.hasClients) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([accessSequence, runtime]),
        builder: (context, child) {
          // IMPORTANT:
          // These must be read INSIDE the builder.
          final sequence = accessSequence.sequence;

          // Runtime.accessNumber represents the access currently
          // being processed / completed by the runtime.
          final accessNumber = runtime.accessNumber.value;

          // The sequence pointer is still the authoritative sequence
          // position.
          final pointer = accessSequence.pointer;

          return Column(
            children: [
              _buildHeader(context, sequence.length),

              const Divider(height: 1),

              Expanded(
                child: sequence.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        itemCount: sequence.length,
                        itemBuilder: (context, index) {
                          return _AccessItem(
                            access: sequence[index],
                            index: index,
                            isActive: index == pointer,
                            accessNumber: accessNumber,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.format_list_numbered_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),

          const SizedBox(width: 8),

          Text(
            'Access Sequence',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const Spacer(),

          Text(
            '$count accesses',
            style: textTheme.bodySmall?.copyWith(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Text(
        'No accesses',
        style: textTheme.bodyMedium?.copyWith(fontFamily: 'Nunito'),
      ),
    );
  }
}

class _AccessItem extends StatelessWidget {
  final Access access;
  final int index;
  final bool isActive;
  final int accessNumber;

  const _AccessItem({
    required this.access,
    required this.index,
    required this.isActive,
    required this.accessNumber,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = isActive
        ? colorScheme.primaryContainer
        : Colors.transparent;

    final foregroundColor = isActive
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 16,
                color: foregroundColor.withValues(alpha: 0.6),
              ),
            ),
          ),

          _buildTypeBadge(context),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              _formatAddress(access.address),
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 18,
                color: foregroundColor,
              ),
            ),
          ),

          if (isActive)
            Icon(
              Icons.play_arrow_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isLoad = access.type == AccessType.load;

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: isLoad
            ? colorScheme.secondaryContainer
            : colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        isLoad ? 'LOAD' : 'STORE',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isLoad
              ? colorScheme.onSecondaryContainer
              : colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }

  String _formatAddress(int address) {
    return '0x${address.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }
}
