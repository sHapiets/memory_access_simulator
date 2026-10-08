import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/cache.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';

class CacheWidget extends StatefulWidget {
  const CacheWidget({super.key});

  @override
  State<CacheWidget> createState() => _CacheWidgetState();
}

class _CacheWidgetState extends State<CacheWidget> {
  final ScrollController _scrollController = ScrollController();

  Cache get cache => Cache.singleton;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 300,
      height: 360,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          _buildHeader(context),

          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: Runtime.singleton.accessNumber,
              builder: (context, _, child) {
                return _buildCache(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final config = Configuration.singleton;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.memory_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),

          const SizedBox(width: 8),

          Text(
            'Cache',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const Spacer(),

          Text(
            '${config.cacheSizeBlocks} lines',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCache(BuildContext context) {
    final config = Configuration.singleton;
    final theme = Theme.of(context);

    final setCount = config.cacheSets;
    final linesPerSet = config.cacheSetSizeBlocks;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(10),
      child: ListenableBuilder(
        listenable: Runtime.singleton,
        builder: (context, child) {
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: setCount,
            itemBuilder: (context, setIndex) {
              final startLine = setIndex * linesPerSet;

              return _buildSet(
                context,
                setIndex: setIndex,
                startLine: startLine,
                linesPerSet: linesPerSet,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSet(
    BuildContext context, {
    required int setIndex,
    required int startLine,
    required int linesPerSet,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          // Set header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.layers_rounded,
                  size: 15,
                  color: colorScheme.primary,
                ),

                const SizedBox(width: 6),

                Text(
                  'INDEX - $setIndex',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),

                const Spacer(),

                Text(
                  '$linesPerSet-way',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Cache lines belonging to this set.
          for (int i = 0; i < linesPerSet; i++)
            _CacheLine(
              lineNumber: startLine + i,
              block: cache.blocks[startLine + i],
              isLast: i == linesPerSet - 1,
            ),
        ],
      ),
    );
  }
}

class _CacheLine extends StatelessWidget {
  final int lineNumber;
  final dynamic block;
  final bool isLast;

  const _CacheLine({
    required this.lineNumber,
    required this.block,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool valid = block.valid;
    final bool dirty = block.dirty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          // Line number
          SizedBox(
            width: 46,
            child: Text(
              'L$lineNumber',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAG',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  valid
                      ? '0x${block.tag.toRadixString(16).toUpperCase()}'
                      : '--',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 14,
                    color: valid
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Valid
          _StatusValue(label: 'V', value: valid ? '1' : '0', active: valid),

          const SizedBox(width: 14),

          // Dirty
          _StatusValue(label: 'D', value: dirty ? '1' : '0', active: dirty),

          const SizedBox(width: 14),

          // Latest access
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'LAST',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                valid ? '${block.latestAccess}' : '--',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusValue extends StatelessWidget {
  final String label;
  final String value;
  final bool active;

  const _StatusValue({
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
