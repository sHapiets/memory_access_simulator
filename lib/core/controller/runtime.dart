import 'package:flutter/cupertino.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/components/cache.dart';
import 'package:memory_access_simulator/core/components/memory.dart';
import 'package:memory_access_simulator/core/components/tlb.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/core/controller/micro_step.dart';
import 'package:memory_access_simulator/foundation/access.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';
import 'package:memory_access_simulator/foundation/parser.dart';

class Runtime extends ChangeNotifier {
  Runtime._();
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

  void runAccess() {
    if (microStep == MicroStep.complete) {
      final sequence = AccessSequence.singleton;

      if (sequence.pointer >= sequence.sequence.length) {
        return;
      }
    }

    while (microStep != MicroStep.complete) {
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

    notifyListeners();
  }

  void _microInitializeGetTranslation() {
    final config = Configuration.singleton;
    final accSequence = AccessSequence.singleton;

    accSequence.pointer += 1;

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

      microStep = MicroStep.intializeGetData;
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
    connectVAtoPageTable = false;
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
      microStep = MicroStep.complete;
      return;
    }

    // CACHE MISS.
    microStep = MicroStep.dram;
    connectPAtoCache = false;
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
    connectCacheToAccessRegister = true;

    microStep = MicroStep.initializeGetTranslation;
  }

  void reset() {
    microStep = MicroStep.initializeGetTranslation;

    _vpn = -1;
    _pageOffset = -1;
    _ppn = -1;
    _physicalAddress = -1;

    _cacheLine = -1;
    _accessType = null;

    _invalidatedVPN = -1;
    _replacedPagePPN = -1;

    _resetConnections();

    final accSequence = AccessSequence.singleton;
    accSequence.pointer = -1;

    // TODO: Add resets of all other components
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
