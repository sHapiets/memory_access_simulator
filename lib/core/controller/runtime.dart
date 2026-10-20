import 'package:flutter/cupertino.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/components/cache.dart';
import 'package:memory_access_simulator/core/components/connection.dart';
import 'package:memory_access_simulator/core/components/memory.dart';
import 'package:memory_access_simulator/core/components/tlb.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/core/controller/micro_step.dart';
import 'package:memory_access_simulator/foundation/access.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';
import 'package:memory_access_simulator/foundation/cache_block.dart';
import 'package:memory_access_simulator/foundation/dynamic_memory_page.dart';
import 'package:memory_access_simulator/foundation/page_table_entry.dart';
import 'package:memory_access_simulator/foundation/parser.dart';
import 'package:memory_access_simulator/foundation/tlb_entry.dart';
import 'dart:convert';

class Runtime extends ChangeNotifier {
  Runtime._() {
    _saveInitialSnapshot();
  }
  static final singleton = Runtime._();

  MicroStep microStep = MicroStep.initializeGetTranslation;
  int microStepNumber = 1;

  int _vpn = -1;
  int _pageOffset = -1;
  int _ppn = -1;
  int _physicalAddress = -1;

  int _tlbEntry = -1;
  int _cacheLine = -1;
  AccessType? _accessType;

  int _invalidatedVPN = -1;
  int _replacedPagePPN = -1;
  int _replacedDirtyLinePPN = -1;

  int get getVPN => _vpn;
  int get getPPN => _ppn;
  int get getPageOffset => _pageOffset;
  int get getPhysicalAddress => _physicalAddress;
  int get getCacheLine => _cacheLine;
  int get getBlockOffset => Parser.cacheOffsetFromAddress(
    _physicalAddress,
    Configuration.singleton.blockSizeBytes,
  );
  int get getInvalidatedVPN => _invalidatedVPN;
  int get getReplacedPagePPN => _replacedPagePPN;
  int get getReplacedDirtyLinePPN => _replacedDirtyLinePPN;

  Connection connectVAtoTLB = Connection.newConnection();
  Connection connectVAtoPageTable = Connection.newConnection();
  Connection connectPageTableToTLB = Connection.newConnection();
  Connection connectVAtoMMU = Connection.newConnection();

  Connection connectMMUtoDisk = Connection.newConnection();
  Connection connectDiskToDRAM = Connection.newConnection();
  Connection connectDRAMtoDisk = Connection.newConnection();
  Connection connectMMUtoPageTable = Connection.newConnection();

  Connection connectTLBtoPA = Connection.newConnection();
  Connection connectVAtoPA = Connection.newConnection();
  Connection connectPAtoCache = Connection.newConnection();
  Connection connectPAtoDRAM = Connection.newConnection();
  Connection connectDRAMtoCache = Connection.newConnection();
  Connection connectCacheToDRAMFromLineEviction = Connection.newConnection();
  Connection connectCacheToDRAMFromPageEviction = Connection.newConnection();

  Connection connectCacheToAccessRegister = Connection.newConnection();
  Connection connectAccessRegisterToCache = Connection.newConnection();

  bool get tlbHit =>
      connectTLBtoPA.active &&
      (!connectVAtoPageTable.active && !connectVAtoMMU.active);
  bool get tlbMiss => connectVAtoPageTable.active;
  bool get cacheHit =>
      connectCacheToAccessRegister.active && (!connectPAtoDRAM.active);
  bool get cacheMiss => connectPAtoDRAM.active;
  bool get pageFault => connectVAtoMMU.active;

  final List<_RuntimeSnapshot> _history = [];
  int _historyIndex = -1;

  bool get canUndo => _historyIndex > 0;

  bool get canRedo => _historyIndex >= 0 && _historyIndex < _history.length - 1;

  int get historyLength => _history.length;

  int get historyPosition => _historyIndex;

  _RuntimeSnapshot? get lastRuntimeSnapshot {
    if (_historyIndex > 0) {
      return _history[_historyIndex - 1];
    }
  }

  RuntimeChange lastChange = RuntimeChange.step;

  void _saveInitialSnapshot() {
    _history.clear();
    _history.add(_RuntimeSnapshot.capture(this));
    _historyIndex = 0;
  }

  /// Records the current state as the starting point for the next microstep.
  /// If the user has undone some steps, running again discards the redo branch.
  void _prepareHistoryForMicrostep() {
    if (_historyIndex < 0) {
      _history.add(_RuntimeSnapshot.capture(this));
      _historyIndex = 0;
      return;
    }

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    // Account for state changes made outside Runtime since the last step.
    _history[_historyIndex] = _RuntimeSnapshot.capture(this);
  }

  void _recordHistoryStep() {
    _history.add(_RuntimeSnapshot.capture(this));
    _historyIndex = _history.length - 1;
  }

  /// Restores the state before the most recently recorded microstep.
  bool undo() {
    if (!canUndo) return false;

    _historyIndex--;
    _history[_historyIndex].restore(this);

    lastChange = RuntimeChange.undo;

    AccessSequence.singleton.notifyListeners();
    notifyListeners();

    return true;
  }

  /// Restores the next recorded state without executing the algorithm again.
  bool redo() {
    if (!canRedo) return false;

    _historyIndex++;
    _history[_historyIndex].restore(this);

    lastChange = RuntimeChange.redo;

    AccessSequence.singleton.notifyListeners();
    notifyListeners();

    return true;
  }

  void runAccess() {
    if (microStep == MicroStep.complete) {
      final sequence = AccessSequence.singleton;

      if (sequence.pointer >= sequence.sequence.length) {
        return;
      }
    }

    if (microStep == MicroStep.initializeGetTranslation) {
      microRun();
    }

    while (microStep != MicroStep.initializeGetTranslation) {
      microRun();
    }
  }

  void microRun() {
    if (microStep == MicroStep.complete) {
      final accSequence = AccessSequence.singleton;

      if (accSequence.pointer >= accSequence.sequence.length) {
        return;
      }
    }

    _prepareHistoryForMicrostep();

    microStepNumber++;

    switch (microStep) {
      case MicroStep.initializeGetTranslation:
        _microInitializeGetTranslation();
        break;

      case MicroStep.tlb:
        _microTLB();
        break;

      case MicroStep.pageTable:
        _microPageTable();
        break;

      case MicroStep.pageFaultEviction:
        _microPageFaultEviction();
        break;

      case MicroStep.pageFaultLoad:
        _microPageFaultLoad();
        break;

      case MicroStep.intializeGetData:
        _microInitializeGetData();
        break;

      case MicroStep.cache:
        _microCache();
        break;

      case MicroStep.dram:
        _microDRAM();
        break;

      case MicroStep.complete:
        _microComplete();
        break;
    }

    _recordHistoryStep();

    lastChange = RuntimeChange.step;
    notifyListeners();
  }

  void _microInitializeGetTranslation() {
    final config = Configuration.singleton;

    microStepNumber = 1;

    final accSequence = AccessSequence.singleton;
    accSequence.pointer += 1;

    if (accSequence.pointer >= accSequence.sequence.length) {
      accSequence.pointer -= 1;
      return;
    }

    final Access currentAccess = accSequence.sequence[accSequence.pointer];

    _accessType = currentAccess.type;

    _pageOffset = Parser.pageOffsetFromAddress(
      currentAccess.address,
      config.pageSizeBytes,
    );

    _vpn = Parser.pageNumberFromAddress(
      currentAccess.address,
      config.pageSizeBytes,
    );

    _ppn = -1;
    _physicalAddress = -1;
    _cacheLine = -1;

    _invalidatedVPN = -1;
    _replacedPagePPN = -1;
    _replacedDirtyLinePPN = -1;

    _resetConnections();

    connectVAtoTLB.setActive(microStepNumber);

    microStep = MicroStep.tlb;
  }

  void _microTLB() {
    final accSequence = AccessSequence.singleton;
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    final ppnFromTLB = tlb.getPPN(_vpn);

    if (ppnFromTLB != -1) {
      // TLB HIT
      _ppn = ppnFromTLB;

      _tlbEntry = tlb.accessEntry(_vpn, accSequence.pointer);

      connectPAtoCache.setActive(microStepNumber);
      connectTLBtoPA.setActive(microStepNumber);
      connectVAtoPA.setActive(microStepNumber);

      _finishTranslation();

      microStep = MicroStep.cache;
      return;
    }

    // TLB MISS.
    microStep = MicroStep.pageTable;
    connectVAtoTLB.setInactiveOnly();
    connectVAtoPageTable.setActive(microStepNumber);
  }

  void _microPageTable() {
    final accSequence = AccessSequence.singleton;
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    if (mem.isPageLoaded(_vpn)) {
      // PAGE TABLE HIT
      _ppn = mem.getPPNFromPageTable(_vpn);

      _tlbEntry = tlb.addEntry(_vpn, _ppn, accSequence.pointer);
      connectPageTableToTLB.setActive(microStepNumber);

      microStep = MicroStep.intializeGetData;
      return;
    }

    // PAGE FAULT.
    connectVAtoMMU.setActive(microStepNumber);
    connectMMUtoDisk.setActive(microStepNumber);

    final ppnForPageLoad = mem.findFreePage();

    if (ppnForPageLoad == -1) {
      microStep = MicroStep.pageFaultEviction;
    } else {
      // There is already a free page.
      _ppn = ppnForPageLoad;
      microStep = MicroStep.pageFaultLoad;
    }
  }

  void _microPageFaultEviction() {
    final tlb = TLB.singleton;
    final cache = Cache.singleton;
    final mem = Memory.singleton;

    _invalidatedVPN = mem.omitLoadablePage();

    final bool isReplacedPageAlreadyDirty = mem.isDirtyVPN(_invalidatedVPN);

    _replacedPagePPN = mem.getPPNFromPageTable(_invalidatedVPN);

    tlb.invalidateEntry(_invalidatedVPN);

    final bool isReplacedPageDirtyFromCache = cache.invalidateCacheLineFromPPN(
      _replacedPagePPN,
    );

    if (isReplacedPageDirtyFromCache) {
      mem.dirtyVPNEntry(_invalidatedVPN);

      // TODO: Cache writeback stats / delay.
      connectCacheToDRAMFromPageEviction.setActive(microStepNumber);

      // TODO: Page writeback stats / delay.
      connectDRAMtoDisk.setActive(microStepNumber);
    } else if (isReplacedPageAlreadyDirty) {
      // TODO: Page writeback stats / delay.
      connectDRAMtoDisk.setActive(microStepNumber);
    }

    _ppn = _replacedPagePPN;

    microStep = MicroStep.pageFaultLoad;
  }

  void _microPageFaultLoad() {
    final accSequence = AccessSequence.singleton;
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    mem.loadPageFromDisk(_vpn, _ppn);
    connectDiskToDRAM.setActive(microStepNumber);
    connectMMUtoPageTable.setActive(microStepNumber);

    _tlbEntry = tlb.addEntry(_vpn, _ppn, accSequence.pointer);
    connectPageTableToTLB.setActive(microStepNumber);

    microStep = MicroStep.intializeGetData;
  }

  void _microInitializeGetData() {
    connectPAtoCache.setActive(microStepNumber);
    connectTLBtoPA.setActive(microStepNumber);
    connectVAtoPA.setActive(microStepNumber);

    _finishTranslation();

    microStep = MicroStep.cache;
  }

  void _finishTranslation() {
    final config = Configuration.singleton;

    _physicalAddress = Parser.addressFromPageComponents(
      _ppn,
      _pageOffset,
      config.pageSizeBytes,
    );
  }

  void _microCache() {
    final cache = Cache.singleton;

    _cacheLine = cache.getCacheLine(_physicalAddress);

    if (_cacheLine != -1) {
      // CACHE HIT.
      _finishData();

      if (_accessType == AccessType.load) {
        connectCacheToAccessRegister.setActive(microStepNumber);
      } else if (_accessType == AccessType.store) {
        connectAccessRegisterToCache.setActive(microStepNumber);
      }

      microStep = MicroStep.initializeGetTranslation;

      return;
    }

    // CACHE MISS.
    microStep = MicroStep.dram;
    connectPAtoDRAM.setActive(microStepNumber);
  }

  void _microDRAM() {
    final cache = Cache.singleton;
    final mem = Memory.singleton;
    final accSequence = AccessSequence.singleton;

    mem.updatePageAccess(_ppn, accSequence.pointer);

    _cacheLine = cache.findFreeCacheLine(_physicalAddress);

    if (_cacheLine == -1) {
      _cacheLine = cache.findReplaceCacheLine(_physicalAddress);
    }

    _replacedDirtyLinePPN = cache.loadBlockFromMemory(
      _cacheLine,
      _physicalAddress,
    );
    connectDRAMtoCache.setActive(microStepNumber);

    if (_replacedDirtyLinePPN != -1) {
      // TODO: Cache writeback delay / stats.
      mem.dirtyVPNEntryFromPPN(_replacedDirtyLinePPN);
      connectCacheToDRAMFromLineEviction.setActive(microStepNumber);
    }

    _finishData();
    microStep = MicroStep.complete;
  }

  void _finishData() {
    final accSequence = AccessSequence.singleton;
    final cache = Cache.singleton;

    cache.accessCacheLine(_cacheLine, _accessType!, accSequence.pointer);
    // TODO: ConnectCacheToDataRegister
  }

  void _microComplete() {
    if (_accessType == AccessType.load) {
      connectCacheToAccessRegister.setActive(microStepNumber);
    } else if (_accessType == AccessType.store) {
      connectAccessRegisterToCache.setActive(microStepNumber);
    }

    microStep = MicroStep.initializeGetTranslation;
  }

  void reset() {
    microStep = MicroStep.initializeGetTranslation;
    microStepNumber = 1;

    _vpn = -1;
    _pageOffset = -1;
    _ppn = -1;
    _physicalAddress = -1;

    _tlbEntry = -1;
    _cacheLine = -1;
    _accessType = null;

    _invalidatedVPN = -1;
    _replacedPagePPN = -1;
    _replacedDirtyLinePPN = -1;

    final accSequence = AccessSequence.singleton;
    accSequence.restart();

    _resetConnections();

    // External resets
    TLB.singleton.resetTLB();
    Memory.singleton.resetMemory();
    Cache.singleton.resetCache();

    _saveInitialSnapshot();

    lastChange = RuntimeChange.reset;

    notifyListeners();
  }

  Map<String, dynamic> exportSession() {
    return {
      'format': 'memory_access_simulator',
      'version': 1,
      'configuration': {
        'blockSizeBytes': Configuration.singleton.blockSizeBytes,
        'pageSizeBlocks': Configuration.singleton.pageSizeBlocks,
        'cacheSizeBlocks': Configuration.singleton.cacheSizeBlocks,
        'cacheSets': Configuration.singleton.cacheSets,
        'tlbSize': Configuration.singleton.tlbSize,
        'dynamicSizePages': Configuration.singleton.dynamicSizePages,
        'vpnBits': Configuration.singleton.vpnBits,
      },
      'currentState': _RuntimeSnapshot.capture(this).toJson(),
      'history': _history.map((snapshot) => snapshot.toJson()).toList(),
      'historyIndex': _historyIndex,
    };
  }

  /// Converts the current session into a JSON string suitable for a .mas file.
  String exportSessionJson() {
    return const JsonEncoder.withIndent('  ').convert(exportSession());
  }

  /// Loads a session previously produced by [exportSession].
  ///
  /// All parsing and validation happens before any singleton is modified.
  void importSession(Map<String, dynamic> json) {
    final session = _ParsedSession.fromJson(json);

    // The snapshots must agree with the configuration being imported.
    session.validateComponentSizes();

    // Apply configuration first because component dimensions depend on it.
    final config = Configuration.singleton;
    config
      ..blockSizeBytes = session.blockSizeBytes
      ..pageSizeBlocks = session.pageSizeBlocks
      ..cacheSizeBlocks = session.cacheSizeBlocks
      ..cacheSets = session.cacheSets
      ..tlbSize = session.tlbSize
      ..dynamicSizePages = session.dynamicSizePages
      ..vpnBits = session.vpnBits;

    // Restore the exact saved current state.
    session.currentState.restore(this);

    // Restore the complete undo/redo timeline.
    _history
      ..clear()
      ..addAll(session.history);
    _historyIndex = session.historyIndex;

    // Refresh widgets that listen to the runtime or access sequence.
    lastChange = RuntimeChange.reset;
    AccessSequence.singleton.notifyListeners();
    notifyListeners();
  }

  void importSessionJson(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! Map) {
      throw const FormatException(
        'The session file must contain a JSON object.',
      );
    }

    importSession(Map<String, dynamic>.from(decoded));
  }

  void _resetConnections() {
    connectVAtoTLB.reset();
    connectVAtoPageTable.reset();
    connectPageTableToTLB.reset();
    connectVAtoMMU.reset();

    connectMMUtoDisk.reset();
    connectDiskToDRAM.reset();
    connectDRAMtoDisk.reset();
    connectMMUtoPageTable.reset();

    connectTLBtoPA.reset();
    connectVAtoPA.reset();
    connectPAtoCache.reset();
    connectPAtoDRAM.reset();
    connectDRAMtoCache.reset();
    connectCacheToDRAMFromPageEviction.reset();
    connectCacheToDRAMFromLineEviction.reset();

    connectAccessRegisterToCache.reset();
    connectCacheToAccessRegister.reset();
  }
}

class _ParsedSession {
  final int blockSizeBytes;
  final int pageSizeBlocks;
  final int cacheSizeBlocks;
  final int cacheSets;
  final int tlbSize;
  final int dynamicSizePages;
  final int vpnBits;

  final _RuntimeSnapshot currentState;
  final List<_RuntimeSnapshot> history;
  final int historyIndex;

  _ParsedSession({
    required this.blockSizeBytes,
    required this.pageSizeBlocks,
    required this.cacheSizeBlocks,
    required this.cacheSets,
    required this.tlbSize,
    required this.dynamicSizePages,
    required this.vpnBits,
    required this.currentState,
    required this.history,
    required this.historyIndex,
  });

  factory _ParsedSession.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'memory_access_simulator') {
      throw const FormatException(
        'This is not a Memory Access Simulator file.',
      );
    }

    if (json['version'] != 1) {
      throw FormatException(
        'Unsupported session file version: ${json['version']}',
      );
    }

    final config = _jsonMap(json['configuration'], 'configuration');

    final blockSizeBytes = _jsonInt(config, 'blockSizeBytes');
    final pageSizeBlocks = _jsonInt(config, 'pageSizeBlocks');
    final cacheSizeBlocks = _jsonInt(config, 'cacheSizeBlocks');
    final cacheSets = _jsonInt(config, 'cacheSets');
    final tlbSize = _jsonInt(config, 'tlbSize');
    final dynamicSizePages = _jsonInt(config, 'dynamicSizePages');
    final vpnBits = _jsonInt(config, 'vpnBits');

    _validateConfiguration(
      blockSizeBytes: blockSizeBytes,
      pageSizeBlocks: pageSizeBlocks,
      cacheSizeBlocks: cacheSizeBlocks,
      cacheSets: cacheSets,
      tlbSize: tlbSize,
      dynamicSizePages: dynamicSizePages,
      vpnBits: vpnBits,
    );

    final currentState = _RuntimeSnapshot.fromJson(
      _jsonMap(json['currentState'], 'currentState'),
    );

    final historyJson = json['history'];
    if (historyJson is! List || historyJson.isEmpty) {
      throw const FormatException('Session history must not be empty.');
    }

    final history = historyJson.map((item) {
      return _RuntimeSnapshot.fromJson(_jsonMap(item, 'history entry'));
    }).toList();

    final historyIndex = _jsonInt(json, 'historyIndex');

    if (historyIndex < 0 || historyIndex >= history.length) {
      throw const FormatException('Invalid history index.');
    }

    return _ParsedSession(
      blockSizeBytes: blockSizeBytes,
      pageSizeBlocks: pageSizeBlocks,
      cacheSizeBlocks: cacheSizeBlocks,
      cacheSets: cacheSets,
      tlbSize: tlbSize,
      dynamicSizePages: dynamicSizePages,
      vpnBits: vpnBits,
      currentState: currentState,
      history: history,
      historyIndex: historyIndex,
    );
  }

  void validateComponentSizes() {
    final expectedCacheBlocks = cacheSizeBlocks;
    final expectedTlbEntries = tlbSize;
    final expectedDynamicPages = dynamicSizePages;
    final expectedPageTableEntries = 1 << vpnBits;

    void check(_RuntimeSnapshot snapshot, String label) {
      if (snapshot.cacheBlocks.length != expectedCacheBlocks ||
          snapshot.tlbEntries.length != expectedTlbEntries ||
          snapshot.dynamicPages.length != expectedDynamicPages ||
          snapshot.pageTable.length != expectedPageTableEntries) {
        throw FormatException(
          '$label has component sizes that do not match its configuration.',
        );
      }

      if (snapshot.sequencePointer < -1 ||
          snapshot.sequencePointer >= snapshot.sequence.length) {
        throw FormatException('$label has an invalid access-sequence pointer.');
      }
    }

    check(currentState, 'Current state');

    for (var i = 0; i < history.length; i++) {
      check(history[i], 'History entry $i');
    }
  }
}

void _validateConfiguration({
  required int blockSizeBytes,
  required int pageSizeBlocks,
  required int cacheSizeBlocks,
  required int cacheSets,
  required int tlbSize,
  required int dynamicSizePages,
  required int vpnBits,
}) {
  bool isPowerOfTwo(int value) => value > 0 && (value & (value - 1)) == 0;

  if (!isPowerOfTwo(blockSizeBytes)) {
    throw const FormatException('Block size must be a positive power of two.');
  }

  if (!isPowerOfTwo(pageSizeBlocks)) {
    throw const FormatException(
      'Blocks per page must be a positive power of two.',
    );
  }

  if (!isPowerOfTwo(cacheSets) ||
      cacheSizeBlocks <= 0 ||
      cacheSets > cacheSizeBlocks ||
      cacheSizeBlocks % cacheSets != 0) {
    throw const FormatException('Invalid cache size or set configuration.');
  }

  if (tlbSize <= 0) {
    throw const FormatException('TLB size must be positive.');
  }

  if (!isPowerOfTwo(dynamicSizePages)) {
    throw const FormatException(
      'DRAM page count must be a positive power of two.',
    );
  }

  // Keep shifts and page-table allocation within a reasonable range.
  if (vpnBits < 1 || vpnBits > 20) {
    throw const FormatException('VPN bits must be between 1 and 20.');
  }
}

Map<String, dynamic> _jsonMap(dynamic value, String label) {
  if (value is! Map) {
    throw FormatException('Invalid $label: expected an object.');
  }

  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw FormatException('Invalid $label: expected string keys.');
  }
}

int _jsonInt(Map<String, dynamic> map, String key) {
  final value = map[key];

  if (value is! int) {
    throw FormatException('Invalid or missing integer field: $key.');
  }

  return value;
}

bool _jsonBool(Map<String, dynamic> map, String key) {
  final value = map[key];

  if (value is! bool) {
    throw FormatException('Invalid or missing boolean field: $key.');
  }

  return value;
}

String _jsonString(Map<String, dynamic> map, String key) {
  final value = map[key];

  if (value is! String) {
    throw FormatException('Invalid or missing string field: $key.');
  }

  return value;
}

class _RuntimeSnapshot {
  // Runtime execution state.
  final MicroStep microStep;
  final int microStepNumber;
  final int vpn;
  final int pageOffset;
  final int ppn;
  final int physicalAddress;
  final int tlbEntry;
  final int cacheLine;
  final AccessType? accessType;
  final int invalidatedVPN;
  final int replacedPagePPN;
  final int replacedDirtyLinePPN;

  // Connection flags.
  final Map<String, Connection> connections;

  // Access sequence.
  final List<Access> sequence;
  final int sequencePointer;

  // Component state.
  final List<CacheBlock> cacheBlocks;
  final List<TLBEntry> tlbEntries;
  final List<DynamicMemoryPage> dynamicPages;
  final List<PageTableEntry> pageTable;

  _RuntimeSnapshot({
    required this.microStep,
    required this.microStepNumber,
    required this.vpn,
    required this.pageOffset,
    required this.ppn,
    required this.physicalAddress,
    required this.tlbEntry,
    required this.cacheLine,
    required this.accessType,
    required this.invalidatedVPN,
    required this.replacedPagePPN,
    required this.replacedDirtyLinePPN,
    required this.connections,
    required this.sequence,
    required this.sequencePointer,
    required this.cacheBlocks,
    required this.tlbEntries,
    required this.dynamicPages,
    required this.pageTable,
  });

  factory _RuntimeSnapshot.capture(Runtime runtime) {
    final accessSequence = AccessSequence.singleton;
    final cache = Cache.singleton;
    final tlb = TLB.singleton;
    final memory = Memory.singleton;

    return _RuntimeSnapshot(
      microStep: runtime.microStep,
      microStepNumber: runtime.microStepNumber,
      vpn: runtime._vpn,
      pageOffset: runtime._pageOffset,
      ppn: runtime._ppn,
      physicalAddress: runtime._physicalAddress,
      tlbEntry: runtime._tlbEntry,
      cacheLine: runtime._cacheLine,
      accessType: runtime._accessType,
      invalidatedVPN: runtime._invalidatedVPN,
      replacedPagePPN: runtime._replacedPagePPN,
      replacedDirtyLinePPN: runtime._replacedDirtyLinePPN,

      connections: {
        'connectVAtoTLB': Connection.newConnection()
          ..set(runtime.connectVAtoTLB),
        'connectVAtoPageTable': Connection.newConnection()
          ..set(runtime.connectVAtoPageTable),
        'connectPageTableToTLB': Connection.newConnection()
          ..set(runtime.connectPageTableToTLB),
        'connectVAtoMMU': Connection.newConnection()
          ..set(runtime.connectVAtoMMU),
        'connectMMUtoDisk': Connection.newConnection()
          ..set(runtime.connectMMUtoDisk),
        'connectDiskToDRAM': Connection.newConnection()
          ..set(runtime.connectDiskToDRAM),
        'connectDRAMtoDisk': Connection.newConnection()
          ..set(runtime.connectDRAMtoDisk),
        'connectMMUtoPageTable': Connection.newConnection()
          ..set(runtime.connectMMUtoPageTable),
        'connectTLBtoPA': Connection.newConnection()
          ..set(runtime.connectTLBtoPA),
        'connectVAtoPA': Connection.newConnection()..set(runtime.connectVAtoPA),
        'connectPAtoCache': Connection.newConnection()
          ..set(runtime.connectPAtoCache),
        'connectPAtoDRAM': Connection.newConnection()
          ..set(runtime.connectPAtoDRAM),
        'connectDRAMtoCache': Connection.newConnection()
          ..set(runtime.connectDRAMtoCache),
        'connectCacheToDRAMFromLineEviction': Connection.newConnection()
          ..set(runtime.connectCacheToDRAMFromLineEviction),
        'connectCacheToDRAMFromPageEviction': Connection.newConnection()
          ..set(runtime.connectCacheToDRAMFromPageEviction),
        'connectCacheToAccessRegister': Connection.newConnection()
          ..set(runtime.connectCacheToAccessRegister),
        'connectAccessRegisterToCache': Connection.newConnection()
          ..set(runtime.connectAccessRegisterToCache),
      },

      sequence: accessSequence.sequence
          .map((a) => Access(type: a.type, address: a.address))
          .toList(),
      sequencePointer: accessSequence.pointer,

      cacheBlocks: cache.blocks.map((block) {
        final copy = CacheBlock.newBlock();
        copy.tag = block.tag;
        copy.valid = block.valid;
        copy.dirty = block.dirty;
        copy.latestAccess = block.latestAccess;
        return copy;
      }).toList(),

      tlbEntries: tlb.entries.map((entry) {
        final copy = TLBEntry.newEntry();
        copy.vpn = entry.vpn;
        copy.valid = entry.valid;
        copy.ppn = entry.ppn;
        copy.lastAccess = entry.lastAccess;
        return copy;
      }).toList(),

      dynamicPages: memory.dynamic.map((page) {
        final copy = DynamicMemoryPage.newPage();
        copy.used = page.used;
        copy.lastAccess = page.lastAccess;
        return copy;
      }).toList(),

      pageTable: memory.pageTable.map((entry) {
        final copy = PageTableEntry.newEntry();
        copy.valid = entry.valid;
        copy.dirty = entry.dirty;
        copy.ppn = entry.ppn;
        return copy;
      }).toList(),
    );
  }

  void restore(Runtime runtime) {
    runtime.microStep = microStep;
    runtime.microStepNumber = microStepNumber;

    runtime._vpn = vpn;
    runtime._pageOffset = pageOffset;
    runtime._ppn = ppn;
    runtime._physicalAddress = physicalAddress;
    runtime._tlbEntry = tlbEntry;
    runtime._cacheLine = cacheLine;
    runtime._accessType = accessType;
    runtime._invalidatedVPN = invalidatedVPN;
    runtime._replacedPagePPN = replacedPagePPN;
    runtime._replacedDirtyLinePPN = replacedDirtyLinePPN;

    runtime.connectVAtoTLB.set(connections['connectVAtoTLB']!);
    runtime.connectVAtoPageTable.set(connections['connectVAtoPageTable']!);
    runtime.connectPageTableToTLB.set(connections['connectPageTableToTLB']!);
    runtime.connectVAtoMMU.set(connections['connectVAtoMMU']!);
    runtime.connectMMUtoDisk.set(connections['connectMMUtoDisk']!);
    runtime.connectDiskToDRAM.set(connections['connectDiskToDRAM']!);
    runtime.connectDRAMtoDisk.set(connections['connectDRAMtoDisk']!);
    runtime.connectMMUtoPageTable.set(connections['connectMMUtoPageTable']!);
    runtime.connectTLBtoPA.set(connections['connectTLBtoPA']!);
    runtime.connectVAtoPA.set(connections['connectVAtoPA']!);
    runtime.connectPAtoCache.set(connections['connectPAtoCache']!);
    runtime.connectPAtoDRAM.set(connections['connectPAtoDRAM']!);
    runtime.connectDRAMtoCache.set(connections['connectDRAMtoCache']!);
    runtime.connectCacheToDRAMFromLineEviction.set(
      connections['connectCacheToDRAMFromLineEviction']!,
    );
    runtime.connectCacheToDRAMFromPageEviction.set(
      connections['connectCacheToDRAMFromPageEviction']!,
    );
    runtime.connectCacheToAccessRegister.set(
      connections['connectCacheToAccessRegister']!,
    );
    runtime.connectAccessRegisterToCache.set(
      connections['connectAccessRegisterToCache']!,
    );

    final accessSequence = AccessSequence.singleton;
    accessSequence.sequence = sequence
        .map((a) => Access(type: a.type, address: a.address))
        .toList();
    accessSequence.pointer = sequencePointer;

    final cache = Cache.singleton;
    cache.blocks = cacheBlocks.map((block) {
      final copy = CacheBlock.newBlock();
      copy.tag = block.tag;
      copy.valid = block.valid;
      copy.dirty = block.dirty;
      copy.latestAccess = block.latestAccess;
      return copy;
    }).toList();

    final tlb = TLB.singleton;
    tlb.entries = tlbEntries.map((entry) {
      final copy = TLBEntry.newEntry();
      copy.vpn = entry.vpn;
      copy.valid = entry.valid;
      copy.ppn = entry.ppn;
      copy.lastAccess = entry.lastAccess;
      return copy;
    }).toList();

    final memory = Memory.singleton;
    memory.dynamic = dynamicPages.map((page) {
      final copy = DynamicMemoryPage.newPage();
      copy.used = page.used;
      copy.lastAccess = page.lastAccess;
      return copy;
    }).toList();

    memory.pageTable = pageTable.map((entry) {
      final copy = PageTableEntry.newEntry();
      copy.valid = entry.valid;
      copy.dirty = entry.dirty;
      copy.ppn = entry.ppn;
      return copy;
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'microStep': microStep.name,
      'microStepNumber': microStepNumber,
      'vpn': vpn,
      'pageOffset': pageOffset,
      'ppn': ppn,
      'physicalAddress': physicalAddress,
      'tlbEntry': tlbEntry,
      'cacheLine': cacheLine,
      'accessType': accessType?.name,
      'invalidatedVPN': invalidatedVPN,
      'replacedPagePPN': replacedPagePPN,
      'replacedDirtyLinePPN': replacedDirtyLinePPN,

      'connections': connections.map((name, connection) {
        return MapEntry(name, {
          'active': connection.active,
          'microStepNumber': connection.microStepNumber,
        });
      }),

      'sequence': sequence.map((access) {
        return {'type': access.type.name, 'address': access.address};
      }).toList(),
      'sequencePointer': sequencePointer,

      'cacheBlocks': cacheBlocks.map((block) {
        return {
          'valid': block.valid,
          'dirty': block.dirty,
          'tag': block.tag,
          'latestAccess': block.latestAccess,
        };
      }).toList(),

      'tlbEntries': tlbEntries.map((entry) {
        return {
          'vpn': entry.vpn,
          'valid': entry.valid,
          'ppn': entry.ppn,
          'lastAccess': entry.lastAccess,
        };
      }).toList(),

      'dynamicPages': dynamicPages.map((page) {
        return {'used': page.used, 'lastAccess': page.lastAccess};
      }).toList(),

      'pageTable': pageTable.map((entry) {
        return {'valid': entry.valid, 'dirty': entry.dirty, 'ppn': entry.ppn};
      }).toList(),
    };
  }

  factory _RuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    MicroStep parseMicroStep(String name) {
      try {
        return MicroStep.values.byName(name);
      } catch (_) {
        throw FormatException('Unknown microstep: $name');
      }
    }

    AccessType? parseAccessType(dynamic value) {
      if (value == null) return null;
      if (value is! String) {
        throw const FormatException('Invalid access type.');
      }

      try {
        return AccessType.values.byName(value);
      } catch (_) {
        throw FormatException('Unknown access type: $value');
      }
    }

    final connectionJson = _jsonMap(json['connections'], 'connections');

    // Keep this list aligned with the connections captured by capture().
    const connectionNames = [
      'connectVAtoTLB',
      'connectVAtoPageTable',
      'connectPageTableToTLB',
      'connectVAtoMMU',
      'connectMMUtoDisk',
      'connectDiskToDRAM',
      'connectDRAMtoDisk',
      'connectMMUtoPageTable',
      'connectTLBtoPA',
      'connectVAtoPA',
      'connectPAtoCache',
      'connectPAtoDRAM',
      'connectDRAMtoCache',
      'connectCacheToDRAMFromLineEviction',
      'connectCacheToDRAMFromPageEviction',
      'connectCacheToAccessRegister',
      'connectAccessRegisterToCache',
    ];

    final parsedConnections = <String, Connection>{};

    for (final name in connectionNames) {
      final data = _jsonMap(connectionJson[name], 'connection $name');

      parsedConnections[name] = Connection(
        active: _jsonBool(data, 'active'),
        microStepNumber: _jsonInt(data, 'microStepNumber'),
      );
    }

    List<dynamic> requiredList(Map<String, dynamic> source, String key) {
      final value = source[key];

      if (value is! List) {
        throw FormatException('Invalid or missing list: $key.');
      }

      return value;
    }

    final parsedSequence = requiredList(json, 'sequence').map((item) {
      final data = _jsonMap(item, 'access');

      return Access(
        type: AccessType.values.byName(_jsonString(data, 'type')),
        address: _jsonInt(data, 'address'),
      );
    }).toList();

    final parsedCacheBlocks = requiredList(json, 'cacheBlocks').map((item) {
      final data = _jsonMap(item, 'cache block');

      return CacheBlock(
        valid: _jsonBool(data, 'valid'),
        dirty: _jsonBool(data, 'dirty'),
        tag: _jsonInt(data, 'tag'),
        latestAccess: _jsonInt(data, 'latestAccess'),
      );
    }).toList();

    final parsedTlbEntries = requiredList(json, 'tlbEntries').map((item) {
      final data = _jsonMap(item, 'TLB entry');

      return TLBEntry(
        vpn: _jsonInt(data, 'vpn'),
        valid: _jsonBool(data, 'valid'),
        ppn: _jsonInt(data, 'ppn'),
        lastAccess: _jsonInt(data, 'lastAccess'),
      );
    }).toList();

    final parsedDynamicPages = requiredList(json, 'dynamicPages').map((item) {
      final data = _jsonMap(item, 'dynamic page');

      return DynamicMemoryPage(
        used: _jsonBool(data, 'used'),
        lastAccess: _jsonInt(data, 'lastAccess'),
      );
    }).toList();

    final parsedPageTable = requiredList(json, 'pageTable').map((item) {
      final data = _jsonMap(item, 'page-table entry');

      return PageTableEntry(
        valid: _jsonBool(data, 'valid'),
        dirty: _jsonBool(data, 'dirty'),
        ppn: _jsonInt(data, 'ppn'),
      );
    }).toList();

    return _RuntimeSnapshot(
      microStep: parseMicroStep(_jsonString(json, 'microStep')),
      microStepNumber: _jsonInt(json, 'microStepNumber'),
      vpn: _jsonInt(json, 'vpn'),
      pageOffset: _jsonInt(json, 'pageOffset'),
      ppn: _jsonInt(json, 'ppn'),
      physicalAddress: _jsonInt(json, 'physicalAddress'),
      tlbEntry: _jsonInt(json, 'tlbEntry'),
      cacheLine: _jsonInt(json, 'cacheLine'),
      accessType: parseAccessType(json['accessType']),
      invalidatedVPN: _jsonInt(json, 'invalidatedVPN'),
      replacedPagePPN: _jsonInt(json, 'replacedPagePPN'),
      replacedDirtyLinePPN: _jsonInt(json, 'replacedDirtyLinePPN'),
      connections: parsedConnections,
      sequence: parsedSequence,
      sequencePointer: _jsonInt(json, 'sequencePointer'),
      cacheBlocks: parsedCacheBlocks,
      tlbEntries: parsedTlbEntries,
      dynamicPages: parsedDynamicPages,
      pageTable: parsedPageTable,
    );
  }
}

enum RuntimeChange { step, undo, redo, reset }
