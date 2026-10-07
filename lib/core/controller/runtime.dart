import 'package:flutter/cupertino.dart';
import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/components/cache.dart';
import 'package:memory_access_simulator/core/components/memory.dart';
import 'package:memory_access_simulator/core/components/tlb.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/foundation/access.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';
import 'package:memory_access_simulator/foundation/parser.dart';

enum MicroStep {
  tlb,
  pageTable,
  pageFaultEviction,
  pageFaultLoad,
  cache,
  dram,
  complete,
}

class Runtime {
  Runtime._();
  static final singleton = Runtime._();

  ValueNotifier<int> accessNumber = ValueNotifier(0);

  MicroStep microStep = MicroStep.tlb;

  int _vpn = -1;
  int _pageOffset = -1;
  int _ppn = -1;
  int _physicalAddress = -1;

  int _cacheLine = -1;
  AccessType? _accessType;

  // Used during page replacement.
  int _invalidatedVPN = -1;
  int _replacedPagePPN = -1;

  void runAccess() {
    _prepareAccess();

    while (microStep != MicroStep.complete) {
      microRun();
    }
  }

  void microRun() {
    switch (microStep) {
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
  }

  void _prepareAccess() {
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

      // Translation succeeded.
      // Skip all other 1.X stages.
      microStep = MicroStep.cache;
      return;
    }

    // TLB MISS.
    // Continue to page table.
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

      // Translation succeeded.
      // Skip page-fault stages.
      microStep = MicroStep.cache;
      return;
    }

    // PAGE FAULT.
    //
    // We need to determine whether an eviction is necessary.
    final ppnForPageLoad = mem.findFreePage();

    if (ppnForPageLoad == -1) {
      // DRAM is full.
      microStep = MicroStep.pageFaultEviction;
    } else {
      // There is already a free page.
      // No eviction/writeback is required.
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

    // Invalidate old translation.
    tlb.invalidateEntry(_invalidatedVPN);

    // Invalidate cache lines belonging to the replaced physical page.
    final bool isReplacedPageDirtyFromCache = cache.invalidateCacheLineFromPPN(
      _replacedPagePPN,
    );

    if (isReplacedPageDirtyFromCache) {
      // Cache contained dirty data for the page being evicted.
      //
      // TODO:
      // Cache writeback stats / delay.
      //
      mem.dirtyVPNEntry(_invalidatedVPN);

      // TODO:
      // Page writeback stats / delay.
    } else if (isReplacedPageAlreadyDirty) {
      // Page table already says that this page is dirty.
      //
      // TODO:
      // Page writeback stats / delay.
    }

    // The physical page previously belonging to the evicted VPN
    // will now be reused.
    _ppn = _replacedPagePPN;

    microStep = MicroStep.pageFaultLoad;
  }

  // ---------------------------------------------------------------------------
  // 1.4 Page Fault - load
  // ---------------------------------------------------------------------------

  void _microPageFaultLoad() {
    final tlb = TLB.singleton;
    final mem = Memory.singleton;

    // Load requested page into the selected physical page.
    //
    // This also creates/updates the page-table entry.
    mem.loadPageFromDisk(_vpn, _ppn);

    // Add the newly established translation to the TLB.
    tlb.addEntry(_vpn, _ppn, accessNumber.value);

    mem.updatePageAccess(_ppn, accessNumber.value);

    // Translation is now complete.
    _finishTranslation();

    microStep = MicroStep.cache;
  }

  // ---------------------------------------------------------------------------
  // Finish virtual -> physical translation
  // ---------------------------------------------------------------------------

  void _finishTranslation() {
    final config = Configuration.singleton;

    _physicalAddress = Parser.addressFromPageComponents(
      _ppn,
      _pageOffset,
      config.pageSizeBytes,
    );
  }

  // ---------------------------------------------------------------------------
  // 2.1 Cache
  // ---------------------------------------------------------------------------

  void _microCache() {
    final cache = Cache.singleton;

    _cacheLine = cache.getCacheLine(_physicalAddress);

    if (_cacheLine != -1) {
      // CACHE HIT.
      //
      // The data is already in the cache.
      // No DRAM access is required.
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
      // Cache replacement evicted a dirty block.
      //
      // TODO:
      // Cache writeback delay / stats.
      mem.dirtyVPNEntryFromPPN(replacedLinePPN);
    }

    // The requested block has now been loaded into cache.
    microStep = MicroStep.complete;
    _completeAccess();
  }

  void _completeAccess() {
    final cache = Cache.singleton;

    cache.accessCacheLine(_cacheLine, _accessType!, accessNumber.value);

    final accSequence = AccessSequence.singleton;

    accSequence.pointer += 1;
    accessNumber.value += 1;

    microStep = MicroStep.complete;
  }

  void reset() {
    microStep = MicroStep.tlb;

    _vpn = -1;
    _pageOffset = -1;
    _ppn = -1;
    _physicalAddress = -1;

    _cacheLine = -1;
    _accessType = null;

    _invalidatedVPN = -1;
    _replacedPagePPN = -1;
  }
}
