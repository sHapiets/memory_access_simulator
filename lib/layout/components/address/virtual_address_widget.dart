import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';

class VirtualAddressWidget extends StatelessWidget {
  const VirtualAddressWidget({super.key});

  static const double _width = 500;
  static const double _height = 320;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Configuration.singleton;

    return ListenableBuilder(
      listenable: Runtime.singleton,
      builder: (context, _) {
        final runtime = Runtime.singleton;

        final int vpn = runtime.getVPN;
        final int pageOffset = runtime.getPageOffset;

        final bool hasAddress = vpn >= 0 && pageOffset >= 0;
        final int pageOffsetBits = config.pageOffsetBits;

        final int virtualAddress = hasAddress
            ? (vpn << pageOffsetBits) | pageOffset
            : -1;

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
                // Static header - never animated
                // ============================================================
                _buildHeader(context),

                const SizedBox(height: 6),

                // ============================================================
                // Animated content - only this section changes
                // ============================================================
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.center,
                        fit: StackFit.expand,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.98,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: hasAddress
                        ? SizedBox.expand(
                            key: ValueKey(virtualAddress),
                            child: _buildAddressContent(
                              context,
                              vpn,
                              pageOffset,
                              virtualAddress,
                              config,
                            ),
                          )
                        : const SizedBox.expand(
                            key: ValueKey('empty'),
                            child: Center(child: Text('—')),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // Static Header
  // ==========================================================================

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Icons.search_rounded, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Virtual Address',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Animated Address Content
  // ==========================================================================

  Widget _buildAddressContent(
    BuildContext context,
    int vpn,
    int pageOffset,
    int virtualAddress,
    Configuration config,
  ) {
    final theme = Theme.of(context);

    // ========================================================================
    // Address configuration
    // ========================================================================

    final int vpnBits = config.vpnBits;
    final int pageOffsetBits = config.pageOffsetBits;

    // ========================================================================
    // Virtual address bits
    // ========================================================================

    final String vpnBinary = vpn.toRadixString(2).padLeft(vpnBits, '0');

    final String pageOffsetBinary = pageOffset
        .toRadixString(2)
        .padLeft(pageOffsetBits, '0');

    // ========================================================================
    // Address visualization
    // ========================================================================

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Hexadecimal virtual address
        Expanded(
          child: Center(
            child: Text(
              '0x${virtualAddress.toRadixString(16).toUpperCase().padLeft((vpnBits + pageOffsetBits + 3) ~/ 4, '0')}',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),

        const Divider(),
        const SizedBox(height: 10),

        // Virtual memory segmentation
        _SegmentationRow(
          title: 'VIRTUAL MEMORY BIT-SEGMENTATION',
          segments: [
            _Segment(
              label: 'VPN',
              bits: vpnBinary,
              color: theme.colorScheme.onSurface,
            ),
            _Segment(
              label: 'PAGE OFFSET',
              bits: pageOffsetBinary,
              color: Colors.pink,
            ),
          ],
        ),

        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),

        // Decimal address information
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AddressInfo(label: 'VPN', value: vpn.toString()),
            const SizedBox(width: 32),
            _AddressInfo(label: 'PAGE OFFSET', value: pageOffset.toString()),
          ],
        ),
      ],
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

        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
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
          ),
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
      width: _VirtualAddressBitBox.width,
      height: _VirtualAddressBitBox.height,
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
            fontSize: 10,
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
// Shared Bit Box Dimensions
// ============================================================================

class _VirtualAddressBitBox {
  static const double width = 28;
  static const double height = 34;
}
