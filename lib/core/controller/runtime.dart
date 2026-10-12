import 'package:flutter/cupertino.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/components/cache.dart';
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

class Runtime extends ChangeNotifier {
  Runtime._() {
    _saveInitialSnapshot();
  }
  static final singleton = Runtime._();

  MicroStep microStep = MicroStep.initializeGetTranslation;

  int _vpn = -1;
  int _pageOffset = -1;
  int _ppn = -1;
  int _physicalAddress = -1;

  int _tlbEntry = -1;
  int _cacheLine = -1;
  AccessType? _accessType;

  // Used during page replacement.
  int _invalidatedVPN = -1;
  int _replacedPagePPN = -1;

  int get getVPN => _vpn;
  int get getPPN => _ppn;
  int get getPageOffset => _pageOffset;
  int get getPhysicalAddress => _physicalAddress;
  int get getCacheLine => _cacheLine;
  int get getBlockOffset => Parser.cacheOffsetFromAddress(
    _physicalAddress,
    Configuration.singleton.blockSizeBytes,
  );

  bool connectVAtoTLB = false;
  bool connectVAtoPageTable = false;
  bool connectPageTableToTLB = false;
  bool connectVAtoMMU = false;

  bool connectMMUtoDisk = false;
  bool connectDiskToDRAM = false;
  bool connectDRAMtoDisk = false;
  bool connectMMUtoPageTable = false;

  bool connectTLBtoPA = false;
  bool connectVAtoPA = false;
  bool connectPAtoCache = false;
  bool connectPAtoDRAM = false;
  bool connectDRAMtoCache = false;
  bool connectCacheToDRAMFromLineEviction = false;
  bool connectCacheToDRAMFromPageEviction = false;

  bool connectCacheToAccessRegister = false;
  bool connectAccessRegisterToCache = false;

  bool get tlbHit =>
      connectTLBtoPA && (!connectVAtoPageTable && !connectVAtoMMU);
  bool get tlbMiss => connectVAtoPageTable;
  bool get cacheHit => connectCacheToAccessRegister && (!connectPAtoDRAM);
  bool get cacheMiss => connectPAtoDRAM;
  bool get pageFault => connectVAtoMMU;

  final List<_RuntimeSnapshot> _history = [];
  int _historyIndex = -1;

  bool get canUndo => _historyIndex > 0;

  bool get canRedo => _historyIndex >= 0 && _historyIndex < _history.length - 1;

  int get historyLength => _history.length;

  int get historyPosition => _historyIndex;

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

    // Notify both Runtime listeners and AccessSequence listeners.
    AccessSequence.singleton.notifyListeners();
    notifyListeners();

    return true;
  }

  /// Restores the next recorded state without executing the algorithm again.
  bool redo() {
    if (!canRedo) return false;

    _historyIndex++;
    _history[_historyIndex].restore(this);

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

    // Save the completed state.
    _recordHistoryStep();

    notifyListeners();
  }

  void _microInitializeGetTranslation() {
    final config = Configuration.singleton;
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

    _resetConnections();

    connectVAtoTLB = true;

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

      mem.updatePageAccess(_ppn, accSequence.pointer);

      connectPAtoCache = true;
      connectTLBtoPA = true;
      connectVAtoPA = true;

      _finishTranslation();

      microStep = MicroStep.cache;
      return;
    }

    // TLB MISS.
    microStep = MicroStep.pageTable;
    connectVAtoTLB = false;
    connectVAtoPageTable = true;
  }

  void _microPageTable() {
    final accSequence = AccessSequence.singleton;
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    if (mem.isPageLoaded(_vpn)) {
      // PAGE TABLE HIT
      _ppn = mem.getPPNFromPageTable(_vpn);

      _tlbEntry = tlb.addEntry(_vpn, _ppn, accSequence.pointer);
      connectPageTableToTLB = true;

      mem.updatePageAccess(_ppn, accSequence.pointer);

      microStep = MicroStep.intializeGetData;
      return;
    }

    // PAGE FAULT.
    connectVAtoMMU = true;
    connectMMUtoDisk = true;

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
      connectCacheToDRAMFromPageEviction = true;

      // TODO: Page writeback stats / delay.
      connectDRAMtoDisk = true;
    } else if (isReplacedPageAlreadyDirty) {
      // TODO: Page writeback stats / delay.
      connectDRAMtoDisk = true;
    }

    _ppn = _replacedPagePPN;

    microStep = MicroStep.pageFaultLoad;
  }

  void _microPageFaultLoad() {
    final accSequence = AccessSequence.singleton;
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    mem.loadPageFromDisk(_vpn, _ppn);
    connectDiskToDRAM = true;
    connectMMUtoPageTable = true;

    _tlbEntry = tlb.addEntry(_vpn, _ppn, accSequence.pointer);
    connectPageTableToTLB = true;

    mem.updatePageAccess(_ppn, accSequence.pointer);

    microStep = MicroStep.intializeGetData;
  }

  void _microInitializeGetData() {
    connectPAtoCache = true;
    connectTLBtoPA = true;
    connectVAtoPA = true;

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
        connectCacheToAccessRegister = true;
      } else if (_accessType == AccessType.store) {
        connectAccessRegisterToCache = true;
      }

      microStep = MicroStep.initializeGetTranslation;

      return;
    }

    // CACHE MISS.
    microStep = MicroStep.dram;
    connectPAtoDRAM = true;
  }

  void _microDRAM() {
    final cache = Cache.singleton;
    final mem = Memory.singleton;

    _cacheLine = cache.findFreeCacheLine(_physicalAddress);

    if (_cacheLine == -1) {
      _cacheLine = cache.findReplaceCacheLine(_physicalAddress);
    }

    final int replacedLinePPN = cache.loadBlockFromMemory(
      _cacheLine,
      _physicalAddress,
    );
    connectDRAMtoCache = true;

    if (replacedLinePPN != -1) {
      // TODO: Cache writeback delay / stats.
      mem.dirtyVPNEntryFromPPN(replacedLinePPN);
      connectCacheToDRAMFromLineEviction = true;
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
      connectCacheToAccessRegister = true;
    } else if (_accessType == AccessType.store) {
      connectAccessRegisterToCache = true;
    }

    microStep = MicroStep.initializeGetTranslation;
  }

  void reset() {
    microStep = MicroStep.initializeGetTranslation;

    _vpn = -1;
    _pageOffset = -1;
    _ppn = -1;
    _physicalAddress = -1;

    _tlbEntry = -1;
    _cacheLine = -1;
    _accessType = null;

    _invalidatedVPN = -1;
    _replacedPagePPN = -1;

    final accSequence = AccessSequence.singleton;
    accSequence.restart();

    _resetConnections();

    // External resets
    TLB.singleton.resetTLB();
    Memory.singleton.resetMemory();
    Cache.singleton.resetCache();

    _saveInitialSnapshot();

    notifyListeners();
  }

  void _resetConnections() {
    connectVAtoTLB = false;
    connectVAtoPageTable = false;
    connectPageTableToTLB = false;
    connectVAtoMMU = false;

    connectMMUtoDisk = false;
    connectDiskToDRAM = false;
    connectDRAMtoDisk = false;
    connectMMUtoPageTable = false;

    connectTLBtoPA = false;
    connectVAtoPA = false;
    connectPAtoCache = false;
    connectPAtoDRAM = false;
    connectDRAMtoCache = false;
    connectCacheToDRAMFromLineEviction = false;
    connectCacheToDRAMFromPageEviction = false;

    connectCacheToAccessRegister = false;
    connectAccessRegisterToCache = false;
  }
}

class _RuntimeSnapshot {
  // Runtime execution state.
  final MicroStep microStep;
  final int vpn;
  final int pageOffset;
  final int ppn;
  final int physicalAddress;
  final int tlbEntry;
  final int cacheLine;
  final AccessType? accessType;
  final int invalidatedVPN;
  final int replacedPagePPN;

  // Connection flags.
  final Map<String, bool> connections;

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
    required this.vpn,
    required this.pageOffset,
    required this.ppn,
    required this.physicalAddress,
    required this.tlbEntry,
    required this.cacheLine,
    required this.accessType,
    required this.invalidatedVPN,
    required this.replacedPagePPN,
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
      vpn: runtime._vpn,
      pageOffset: runtime._pageOffset,
      ppn: runtime._ppn,
      physicalAddress: runtime._physicalAddress,
      tlbEntry: runtime._tlbEntry,
      cacheLine: runtime._cacheLine,
      accessType: runtime._accessType,
      invalidatedVPN: runtime._invalidatedVPN,
      replacedPagePPN: runtime._replacedPagePPN,

      connections: {
        'connectVAtoTLB': runtime.connectVAtoTLB,
        'connectVAtoPageTable': runtime.connectVAtoPageTable,
        'connectPageTableToTLB': runtime.connectPageTableToTLB,
        'connectVAtoMMU': runtime.connectVAtoMMU,
        'connectMMUtoDisk': runtime.connectMMUtoDisk,
        'connectDiskToDRAM': runtime.connectDiskToDRAM,
        'connectDRAMtoDisk': runtime.connectDRAMtoDisk,
        'connectMMUtoPageTable': runtime.connectMMUtoPageTable,
        'connectTLBtoPA': runtime.connectTLBtoPA,
        'connectVAtoPA': runtime.connectVAtoPA,
        'connectPAtoCache': runtime.connectPAtoCache,
        'connectPAtoDRAM': runtime.connectPAtoDRAM,
        'connectDRAMtoCache': runtime.connectDRAMtoCache,
        'connectCacheToDRAMFromLineEviction':
            runtime.connectCacheToDRAMFromLineEviction,
        'connectCacheToDRAMFromPageEviction':
            runtime.connectCacheToDRAMFromPageEviction,
        'connectCacheToAccessRegister': runtime.connectCacheToAccessRegister,
        'connectAccessRegisterToCache': runtime.connectAccessRegisterToCache,
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

    runtime._vpn = vpn;
    runtime._pageOffset = pageOffset;
    runtime._ppn = ppn;
    runtime._physicalAddress = physicalAddress;
    runtime._tlbEntry = tlbEntry;
    runtime._cacheLine = cacheLine;
    runtime._accessType = accessType;
    runtime._invalidatedVPN = invalidatedVPN;
    runtime._replacedPagePPN = replacedPagePPN;

    runtime.connectVAtoTLB = connections['connectVAtoTLB']!;
    runtime.connectVAtoPageTable = connections['connectVAtoPageTable']!;
    runtime.connectPageTableToTLB = connections['connectPageTableToTLB']!;
    runtime.connectVAtoMMU = connections['connectVAtoMMU']!;
    runtime.connectMMUtoDisk = connections['connectMMUtoDisk']!;
    runtime.connectDiskToDRAM = connections['connectDiskToDRAM']!;
    runtime.connectDRAMtoDisk = connections['connectDRAMtoDisk']!;
    runtime.connectMMUtoPageTable = connections['connectMMUtoPageTable']!;
    runtime.connectTLBtoPA = connections['connectTLBtoPA']!;
    runtime.connectVAtoPA = connections['connectVAtoPA']!;
    runtime.connectPAtoCache = connections['connectPAtoCache']!;
    runtime.connectPAtoDRAM = connections['connectPAtoDRAM']!;
    runtime.connectDRAMtoCache = connections['connectDRAMtoCache']!;
    runtime.connectCacheToDRAMFromLineEviction =
        connections['connectCacheToDRAMFromLineEviction']!;
    runtime.connectCacheToDRAMFromPageEviction =
        connections['connectCacheToDRAMFromPageEviction']!;
    runtime.connectCacheToAccessRegister =
        connections['connectCacheToAccessRegister']!;
    runtime.connectAccessRegisterToCache =
        connections['connectAccessRegisterToCache']!;

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
}
