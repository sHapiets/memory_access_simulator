import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/controller/micro_step.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';

class LogStatisticsWidget extends StatefulWidget {
  const LogStatisticsWidget({super.key});

  @override
  State<LogStatisticsWidget> createState() => _LogStatisticsWidgetState();
}

class _LogStatisticsWidgetState extends State<LogStatisticsWidget> {
  Runtime get runtime => Runtime.singleton;
  AccessSequence get accessSequence => AccessSequence.singleton;

  final ScrollController _logScrollController = ScrollController();
  final List<_LogEntry> _entries = [];

  MicroStep? _previousStep;

  int _completedAccesses = 0;
  int _tlbHits = 0;
  int _tlbMisses = 0;
  int _pageFaults = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;

  @override
  void initState() {
    super.initState();
    _previousStep = runtime.microStep;
    runtime.addListener(_handleRuntimeChanged);
  }

  @override
  void dispose() {
    runtime.removeListener(_handleRuntimeChanged);
    _logScrollController.dispose();
    super.dispose();
  }

  // ================================================================
  // RESET
  // ================================================================

  bool get _isRuntimeReset =>
      runtime.microStep == MicroStep.initializeGetTranslation &&
      runtime.getVPN == -1 &&
      runtime.getPPN == -1 &&
      runtime.getPageOffset == -1 &&
      runtime.getPhysicalAddress == -1;

  void _clearLogAndStatistics() {
    _entries.clear();
    _completedAccesses = 0;
    _tlbHits = 0;
    _tlbMisses = 0;
    _pageFaults = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  void _clearManually() {
    setState(_clearLogAndStatistics);
  }

  // ================================================================
  // FORMATTING
  // ================================================================

  String _formatAddress(int address) =>
      '0x${address.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  String get _accessDescription {
    final sequence = accessSequence.sequence;
    final pointer = accessSequence.pointer;

    if (pointer < 0 || pointer >= sequence.length) {
      return 'Access';
    }

    final access = sequence[pointer];
    final type = access.type == AccessType.load ? 'LOAD' : 'STORE';

    return '$type ${_formatAddress(access.address)}';
  }

  String get _currentAddressDescription {
    final address = runtime.getPhysicalAddress;
    if (address < 0) return '';
    return ' (PA ${_formatAddress(address)})';
  }

  void _addEntry(
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Color? color,
  }) {
    _entries.add(
      _LogEntry(
        message: message,
        icon: icon,
        color: color,
        accessNumber: accessSequence.pointer + 1,
      ),
    );
  }

  // ================================================================
  // RUNTIME EVENTS
  // ================================================================

  void _handleRuntimeChanged() {
    if (!mounted) return;

    if (_isRuntimeReset) {
      setState(() {
        _clearLogAndStatistics();
        _previousStep = runtime.microStep;
      });
      return;
    }

    final completedStep = _previousStep;
    final nextStep = runtime.microStep;

    if (completedStep == null) {
      _previousStep = nextStep;
      return;
    }

    setState(() {
      switch (completedStep) {
        case MicroStep.initializeGetTranslation:
          _addEntry(
            'Starting $_accessDescription: '
            'VPN ${runtime.getVPN}, '
            'offset ${runtime.getPageOffset}.',
            icon: Icons.play_arrow_rounded,
          );
          break;

        case MicroStep.tlb:
          if (runtime.tlbHit) {
            _tlbHits++;
            _addEntry(
              'TLB hit: VPN ${runtime.getVPN} maps to '
              'PPN ${runtime.getPPN}.',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
            );
          } else if (runtime.tlbMiss) {
            _tlbMisses++;
            _addEntry(
              'TLB miss: VPN ${runtime.getVPN} was not found. '
              'Checking the page table.',
              icon: Icons.search_rounded,
              color: Colors.orange,
            );
          }
          break;

        case MicroStep.pageTable:
          if (runtime.pageFault) {
            _pageFaults++;
            _addEntry(
              'Page fault: VPN ${runtime.getVPN} is not in '
              'physical memory.',
              icon: Icons.warning_amber_rounded,
              color: Colors.deepOrange,
            );
          } else if (runtime.connectPageTableToTLB) {
            _addEntry(
              'Page-table hit: VPN ${runtime.getVPN} maps to '
              'PPN ${runtime.getPPN}. TLB entry updated.',
              icon: Icons.table_chart_rounded,
              color: Colors.green,
            );
          }
          break;

        case MicroStep.pageFaultEviction:
          _addEntry(
            'Physical memory is full. Evicting a page to '
            'make room for VPN ${runtime.getVPN}.',
            icon: Icons.swap_horiz_rounded,
            color: Colors.deepOrange,
          );

          if (runtime.connectCacheToDRAMFromPageEviction) {
            _addEntry(
              'Dirty cache data written back during page eviction.',
              icon: Icons.save_alt_rounded,
            );
          }

          if (runtime.connectDRAMtoDisk) {
            _addEntry(
              'Page written back to disk.',
              icon: Icons.storage_rounded,
            );
          }
          break;

        case MicroStep.pageFaultLoad:
          _addEntry(
            'Loaded VPN ${runtime.getVPN} into physical page '
            'PPN ${runtime.getPPN}.',
            icon: Icons.download_rounded,
          );
          break;

        case MicroStep.intializeGetData:
          _addEntry(
            'Address translation complete: '
            'VPN ${runtime.getVPN} → PPN ${runtime.getPPN}. '
            'Physical address '
            '${_formatAddress(runtime.getPhysicalAddress)}.',
            icon: Icons.transform_rounded,
          );
          break;

        case MicroStep.cache:
          if (nextStep == MicroStep.dram) {
            _cacheMisses++;
            _addEntry(
              'Cache miss at PA '
              '${_formatAddress(runtime.getPhysicalAddress)}. '
              'Fetching the block from DRAM.',
              icon: Icons.search_rounded,
              color: Colors.orange,
            );
          } else if (nextStep == MicroStep.initializeGetTranslation) {
            _cacheHits++;
            _completedAccesses++;
            _addEntry(
              'Cache hit$_currentAddressDescription. '
              '$_accessDescription completed.',
              icon: Icons.check_circle_rounded,
              color: Colors.green,
            );
          }
          break;

        case MicroStep.dram:
          _addEntry(
            'DRAM returned the requested cache block.',
            icon: Icons.memory_rounded,
          );

          if (runtime.connectCacheToDRAMFromLineEviction) {
            _addEntry(
              'Dirty cache line evicted; its data will be '
              'written back to DRAM.',
              icon: Icons.save_alt_rounded,
            );
          }
          break;

        case MicroStep.complete:
          _completedAccesses++;
          _addEntry(
            '$_accessDescription completed after the DRAM access'
            '$_currentAddressDescription.',
            icon: Icons.check_circle_rounded,
            color: Colors.green,
          );
          break;
      }

      _previousStep = nextStep;
    });

    // Scroll to the newest event after the frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_logScrollController.hasClients) return;

      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  // ================================================================
  // MAIN BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Divider(height: 1),

          // Log is above and receives most of the available height.
          Expanded(flex: 3, child: _buildLog(context)),

          const Divider(height: 1),

          // Compact statistics at the bottom.
          _buildStatistics(context),
        ],
      ),
    );
  }

  // ================================================================
  // HEADER
  // ================================================================

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Log and Statistics',
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
            IconButton(
              tooltip: 'Clear log and statistics',
              onPressed: _clearManually,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // COMPACT STATISTICS
  // ================================================================

  Widget _buildStatistics(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text(
              'STATISTICS',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _compactStat(context, 'Completed', _completedAccesses),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _compactStat(context, 'Page faults', _pageFaults),
              ),
              const SizedBox(width: 5),
              Expanded(child: _compactStat(context, 'TLB hits', _tlbHits)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(child: _compactStat(context, 'TLB misses', _tlbMisses)),
              const SizedBox(width: 5),
              Expanded(child: _compactStat(context, 'Cache hits', _cacheHits)),
              const SizedBox(width: 5),
              Expanded(
                child: _compactStat(context, 'Cache misses', _cacheMisses),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactStat(BuildContext context, String label, int value) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 9,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SCROLLABLE LOG
  // ================================================================

  Widget _buildLog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 17, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'LOG',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${_entries.length} events',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 28,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No events yet',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Run an access to see the memory hierarchy in action.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Scrollbar(
                  controller: _logScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      return _buildLogEntry(context, _entries[index], index);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLogEntry(BuildContext context, _LogEntry entry, int index) {
    final colors = Theme.of(context).colorScheme;
    final accent = entry.color ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 25,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(entry.icon, size: 17, color: accent),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: index.isEven
                    ? colors.surfaceContainerHighest.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Access ${entry.accessNumber}',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.message,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      height: 1.35,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// LOG ENTRY MODEL
// ==================================================================

class _LogEntry {
  final String message;
  final IconData icon;
  final Color? color;
  final int accessNumber;

  const _LogEntry({
    required this.message,
    required this.icon,
    required this.accessNumber,
    this.color,
  });
}
