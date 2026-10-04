import 'package:memory_access_simulator/core/components/access_sequence.dart';
import 'package:memory_access_simulator/core/components/cache.dart';
import 'package:memory_access_simulator/core/components/memory.dart';
import 'package:memory_access_simulator/core/components/tlb.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/foundation/access.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';
import 'package:memory_access_simulator/foundation/parser.dart';

class Runtime {
  Runtime._();
  static final singleton = Runtime._();

  int accessNumber = 0;

  void reset() {}

  void runAccess() {
    final config = Configuration.singleton;
    final AccessSequence accSequence = AccessSequence.singleton;
    final Access currentAccess = accSequence.sequence[accSequence.pointer];

    // TODO: This setting is only for present VM (always?)
    final pageOffset = Parser.pageOffsetFromAddress(
      currentAccess.address,
      config.pageSizeBytes,
    );
    final vpn = Parser.pageNumberFromAddress(
      currentAccess.address,
      config.pageSizeBytes,
    );

    int ppn = _getTranslation(vpn);

    int physicalAddress = Parser.addressFromPageComponents(
      ppn,
      pageOffset,
      config.pageSizeBytes,
    );

    _getData(physicalAddress, vpn, currentAccess.type);

    accSequence.pointer += 1;
    accessNumber += 1;
  }

  int _getTranslation(int vpn) {
    final tlb = TLB.singleton;
    final cache = Cache.singleton;
    final mem = Memory.singleton;

    // Find translation in TLB
    final ppnFromTLB = tlb.getPPN(vpn);
    if (ppnFromTLB != -1) {
      // TODO: TLB Hit Stats / Delay
      tlb.accessEntry(vpn, accessNumber);
      mem.updatePageAccess(ppnFromTLB, accessNumber);
      return ppnFromTLB;
    }

    // TODO: TLB Miss Stats / Delay
    // Find translation in PageTable
    if (mem.isPageLoaded(vpn)) {
      // TODO: Page Table Stats / Delay
      int ppnFromPageTable = mem.getPPNFromPageTable(vpn);
      tlb.addEntry(vpn, ppnFromPageTable, accessNumber);
      mem.updatePageAccess(ppnFromPageTable, accessNumber);
      return ppnFromPageTable;
    }

    // Page Fault
    int ppnForPageLoad = mem.findFreePage();
    if (ppnForPageLoad == -1) {
      int invalidatedVPN = mem.omitLoadablePage();
      bool isReplacedPageAlreadyDirty = mem.isDirtyVPN(invalidatedVPN);
      ppnForPageLoad = mem.getPPNFromPageTable(invalidatedVPN);

      tlb.invalidateEntry(invalidatedVPN);
      bool isReplacedPageDirtyFromCache = cache.invalidateCacheLineFromPPN(
        ppnForPageLoad,
      );
      if (isReplacedPageDirtyFromCache) {
        // TODO: Cache Writeback Stats / Delay
        mem.dirtyVPNEntry(invalidatedVPN);
        // TODO: Page Writeback Stats / Delay
      } else if (isReplacedPageAlreadyDirty) {
        // TODO: Page Writeback Stats / Delay
      }
    }

    // TODO: Page Load Stats / Delay
    mem.loadPageFromDisk(vpn, ppnForPageLoad);
    tlb.addEntry(vpn, ppnForPageLoad, accessNumber);
    mem.updatePageAccess(ppnForPageLoad, accessNumber);
    return ppnForPageLoad;
  }

  void _getData(int address, int vpn, AccessType accessType) {
    final cache = Cache.singleton;
    final mem = Memory.singleton;

    int cacheLine = cache.getCacheLine(address);

    if (cacheLine != -1) {
      // TODO: Cache Hit
    } else {
      // TODO: Cache Miss Stats / Delay
      cacheLine = cache.findFreeCacheLine(address);
      if (cacheLine == -1) cacheLine = cache.findReplaceCacheLine(address);

      int replacedLinePPN = cache.loadBlockFromMemory(cacheLine, address);
      if (replacedLinePPN != -1) {
        // TODO: Cache Writeback Delay / Stats
        mem.dirtyVPNEntryFromPPN(replacedLinePPN);
      }
    }

    // TODO: Cache Access Delay / Stats
    cache.accessCacheLine(cacheLine, accessType, accessNumber);
  }
}
