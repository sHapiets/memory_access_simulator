import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';

class PhysicalAddressWidget extends StatelessWidget {
  const PhysicalAddressWidget({super.key});

  static const double _bitBoxWidth = 28;
  static const double _bitBoxHeight = 34;

  static const double _width = 500;
  static const double _height = 420;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Configuration.singleton;

    return ListenableBuilder(
      listenable: Runtime.singleton,
      builder: (context, _) {
        final runtime = Runtime.singleton;

        final physicalAddress = runtime.getPhysicalAddress;
        final bool hasAddress = physicalAddress >= 0;

        if (!hasAddress) {
          return _buildEmpty(context);
        }

        // ====================================================================
        // Address configuration
        // ====================================================================

        final int addressBits = config.vpnBits + config.pageOffsetBits;

        // Physical memory segmentation.
        final int pageOffsetBits = config.pageOffsetBits;
        final int ppnBits = addressBits - pageOffsetBits;

        // Cache segmentation.
        final int blockOffsetBits = config.blockOffsetBits;
        final int indexBits = config.cacheIndexBits;
        final int tagBits = addressBits - indexBits - blockOffsetBits;

        // ====================================================================
        // Physical memory bits
        // ====================================================================

        final String ppnBinary = runtime.getPPN
            .toRadixString(2)
            .padLeft(ppnBits, '0');

        final String pageOffsetBinary = runtime.getPageOffset
            .toRadixString(2)
            .padLeft(pageOffsetBits, '0');

        // ====================================================================
        // Cache bits
        // ====================================================================

        final String binary = physicalAddress
            .toRadixString(2)
            .padLeft(addressBits, '0');

        final String tagBitsString = binary.substring(0, tagBits);

        final String indexBitsString = binary.substring(
          tagBits,
          tagBits + indexBits,
        );

        final String blockOffsetBitsString = binary.substring(
          tagBits + indexBits,
        );

        // ====================================================================
        // Decimal values
        // ====================================================================

        final int tag = int.parse(tagBitsString, radix: 2);
        final int index = int.parse(indexBitsString, radix: 2);
        final int blockOffset = int.parse(blockOffsetBitsString, radix: 2);

        final int ppn = int.parse(ppnBinary, radix: 2);
        final int pageOffset = int.parse(pageOffsetBinary, radix: 2);

        return FittedBox(
          child: Container(
            width: _width,
            height: _height,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ============================================================
                // Header
                // ============================================================
                Row(
                  children: [
                    Icon(
                      Icons.memory_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Physical Address',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ============================================================
                // Hexadecimal physical address
                // ============================================================
                Center(
                  child: Text(
                    '0x${physicalAddress.toRadixString(16).toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

                const Divider(),
                const SizedBox(height: 10),

                // ============================================================
                // Cache Segmentation
                // ============================================================
                _SegmentationRow(
                  title: 'CACHE BIT-SEGMENTATION',
                  segments: [
                    _Segment(
                      label: 'TAG',
                      bits: tagBitsString,
                      color: theme.colorScheme.primary,
                    ),
                    _Segment(
                      label: 'INDEX',
                      bits: indexBitsString,
                      color: theme.colorScheme.secondary,
                    ),
                    _Segment(
                      label: 'BLOCK OFFSET',
                      bits: blockOffsetBitsString,
                      color: theme.colorScheme.tertiary,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ============================================================
                // Physical Memory Segmentation
                // ============================================================
                _SegmentationRow(
                  title: 'PHYSICAL MEMORY BIT-SEGMENTATION',
                  segments: [
                    _Segment(
                      label: 'PPN',
                      bits: ppnBinary,
                      color: theme.colorScheme.primary,
                    ),
                    _Segment(
                      label: 'PAGE OFFSET',
                      bits: pageOffsetBinary,
                      color: theme.colorScheme.secondary,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                const Divider(),

                const SizedBox(height: 8),

                // ============================================================
                // Physical memory decimal summary
                // ============================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AddressInfo(label: 'PPN', value: ppn.toString()),
                    const SizedBox(width: 32),
                    _AddressInfo(
                      label: 'PAGE OFFSET',
                      value: pageOffset.toString(),
                    ),
                    const SizedBox(width: 32),
                    _AddressInfo(label: 'TAG', value: tag.toString()),
                    const SizedBox(width: 32),
                    _AddressInfo(label: 'INDEX', value: index.toString()),
                    const SizedBox(width: 32),
                    _AddressInfo(
                      label: 'BLOCK OFFSET',
                      value: blockOffset.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);

    return FittedBox(
      child: Container(
        width: _width,
        height: _height,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.memory_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Physical Address',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const Spacer(),

            Center(
              child: Text(
                '—',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 24,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Segmentation Row
// ============================================================================

class _SegmentationRow extends StatelessWidget {
  const _SegmentationRow({required this.title, required this.segments});

  final String title;
  final List<_Segment> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              _BitSegment(
                label: segments[i].label,
                bits: segments[i].bits,
                color: segments[i].color,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Segment Data
// ============================================================================

class _Segment {
  const _Segment({
    required this.label,
    required this.bits,
    required this.color,
  });

  final String label;
  final String bits;
  final Color color;
}

// ============================================================================
// Address Info
// ============================================================================

class _AddressInfo extends StatelessWidget {
  const _AddressInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Bit Segment
// ============================================================================

class _BitSegment extends StatelessWidget {
  const _BitSegment({
    required this.label,
    required this.bits,
    required this.color,
  });

  final String label;
  final String bits;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --------------------------------------------------------------
        // Segment label
        // --------------------------------------------------------------
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),

        const SizedBox(height: 3),

        // --------------------------------------------------------------
        // Individual bit boxes
        // --------------------------------------------------------------
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < bits.length; i++)
              _BitBox(
                value: bits[i],
                color: color,
                isLast: i == bits.length - 1,
              ),
          ],
        ),

        const SizedBox(height: 2),

        // --------------------------------------------------------------
        // Bit count
        // --------------------------------------------------------------
        Text(
          '${bits.length} bit${bits.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 8,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Individual Bit
// ============================================================================

class _BitBox extends StatelessWidget {
  const _BitBox({
    required this.value,
    required this.color,
    required this.isLast,
  });

  final String value;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: _PhysicalAddressBitBox.width,
      height: _PhysicalAddressBitBox.height,
      margin: EdgeInsets.only(right: isLast ? 0 : 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.2),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ============================================================================
// Shared Bit Box Dimensions
// ============================================================================

class _PhysicalAddressBitBox {
  static const double width = 28;
  static const double height = 34;
}
