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

  ValueNotifier<int> accessNumber = ValueNotifier(0);

  MicroStep microStep = MicroStep.initialize;

  int _vpn = -1;
  int _pageOffset = -1;
  int _ppn = -1;
  int _physicalAddress = -1;

  int _cacheLine = -1;
  AccessType? _accessType;

  // Used during page replacement.
  int _invalidatedVPN = -1;
  int _replacedPagePPN = -1;

  int get getVPN => _vpn;
  int get getPPN => _ppn;
  int get getPageOffset => _pageOffset;
  int get getPhysicalAddress => _physicalAddress;

  void runAccess() {
    if (microStep == MicroStep.complete) {
      final sequence = AccessSequence.singleton;

      if (sequence.pointer >= sequence.sequence.length) {
        return;
      }

      microStep = MicroStep.initialize;
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

      microStep = MicroStep.initialize;
    }

    switch (microStep) {
      case MicroStep.initialize:
        _microInitialize();
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

      case MicroStep.cache:
        _microCache();
        break;

      case MicroStep.dram:
        _microDRAM();
        break;

      case MicroStep.complete:
        break;
    }

    notifyListeners();
  }

  void _microInitialize() {
    final config = Configuration.singleton;
    final accSequence = AccessSequence.singleton;

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

    microStep = MicroStep.tlb;
  }

  void _microTLB() {
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    final ppnFromTLB = tlb.getPPN(_vpn);

    if (ppnFromTLB != -1) {
      // TLB HIT
      _ppn = ppnFromTLB;

      tlb.accessEntry(_vpn, accessNumber.value);

      mem.updatePageAccess(_ppn, accessNumber.value);

      _finishTranslation();

      microStep = MicroStep.cache;
      return;
    }

    // TLB MISS.
    microStep = MicroStep.pageTable;
  }

  void _microPageTable() {
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    if (mem.isPageLoaded(_vpn)) {
      // PAGE TABLE HIT
      _ppn = mem.getPPNFromPageTable(_vpn);

      tlb.addEntry(_vpn, _ppn, accessNumber.value);

      mem.updatePageAccess(_ppn, accessNumber.value);

      _finishTranslation();

      microStep = MicroStep.cache;
      return;
    }

    // PAGE FAULT.
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
      // TODO: Cache writeback stats / delay.
      mem.dirtyVPNEntry(_invalidatedVPN);

      // TODO: Page writeback stats / delay.
    } else if (isReplacedPageAlreadyDirty) {
      // TODO: Page writeback stats / delay.
    }

    _ppn = _replacedPagePPN;

    microStep = MicroStep.pageFaultLoad;
  }

  void _microPageFaultLoad() {
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    mem.loadPageFromDisk(_vpn, _ppn);

    tlb.addEntry(_vpn, _ppn, accessNumber.value);

    mem.updatePageAccess(_ppn, accessNumber.value);

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
      microStep = MicroStep.complete;
      _completeAccess();
      return;
    }

    // CACHE MISS.
    microStep = MicroStep.dram;
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

    if (replacedLinePPN != -1) {
      // TODO: Cache writeback delay / stats.
      mem.dirtyVPNEntryFromPPN(replacedLinePPN);
    }

    // The requested block has now been loaded into cache.
    microStep = MicroStep.complete;
    _completeAccess();
  }

  void _completeAccess() {
    final cache = Cache.singleton;
    final accSequence = AccessSequence.singleton;

    cache.accessCacheLine(_cacheLine, _accessType!, accessNumber.value);

    accSequence.pointer += 1;
    accessNumber.value += 1;

    // The current access is finished.
    microStep = MicroStep.complete;
  }

  void reset() {
    microStep = MicroStep.initialize;

    _vpn = -1;
    _pageOffset = -1;
    _ppn = -1;
    _physicalAddress = -1;

    _cacheLine = -1;
    _accessType = null;

    _invalidatedVPN = -1;
    _replacedPagePPN = -1;

    // TODO: Add resets of all other components
  }
}
