import 'package:flutter/cupertino.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/foundation/dynamic_memory_page.dart';
import 'package:memory_access_simulator/foundation/page_table_entry.dart';

class Memory {
  Memory._() {
    resetMemory();
  }
  static final singleton = Memory._();

  List<DynamicMemoryPage> dynamic = [];
  bool _isValidDynamicPage(int pageNumber) =>
      dynamic.length > pageNumber && pageNumber >= 0;

  List<PageTableEntry> pageTable = [];
  bool _isValidVPN(int vpn) => pageTable.length > vpn && vpn >= 0;

  int getPPNFromPageTable(int vpn) {
    if (!_isValidVPN(vpn)) {
      debugPrint(
        "VPN ERROR: Attempt to access invalid PAGE TABLE ENTRY (VPN): [$vpn]",
      );
      return -1;
    }

    return pageTable[vpn].ppn;
  }

  bool isPageLoaded(int vpn) {
    if (!_isValidVPN(vpn)) {
      debugPrint(
        "VPN ERROR: Attempt to access invalid PAGE TABLE ENTRY (VPN): [$vpn]",
      );
      return false;
    }

    return pageTable[vpn].valid;
  }

  int omitLoadablePage() {
    int ppn = _findFreePage();

    if (ppn == -1) {
      ppn = _findReplacePage();
      for (int vpn = 0; vpn < pageTable.length; vpn++) {
        final pageTableEntry = pageTable[vpn];
        if (pageTableEntry.ppn == ppn) {
          _invalidateVPNEntry(vpn);
          return vpn;
        }
      }
    }

    return -1;
  }

  int loadPageFromDisk(int newVPN, int invalidatedVPN) {
    int ppn = pageTable[invalidatedVPN].ppn;

    _changePPN(vpn: newVPN, ppn: ppn);
    dynamic[ppn].used = true;
    return ppn;
  }

  void updatePageAccess(int ppn, int accessNumber) {
    if (!_isValidDynamicPage(ppn)) {
      debugPrint(
        "PPN ERROR: Attempt to access invalid DYNAMIC PAGE (PPN): [$ppn]",
      );
      return;
    }

    dynamic[ppn].lastAccess = accessNumber;
  }

  void dirtyVPNEntry(int vpn) {
    if (!_isValidVPN(vpn)) {
      debugPrint(
        "VPN ERROR: Attempt to access invalid PAGE TABLE ENTRY (VPN): [$vpn]",
      );
      return;
    }

    pageTable[vpn].dirty = true;
  }

  int _findFreePage() {
    for (int i = 0; i < dynamic.length; i++) {
      if (!dynamic[i].used) {
        return i;
      }
    }

    return -1;
  }

  int _findReplacePage() {
    int selectedReplacePage = 0;

    for (int i = 1; i < dynamic.length; i++) {
      if (dynamic[i].lastAccess < dynamic[selectedReplacePage].lastAccess) {
        selectedReplacePage = i;
      }
    }

    return selectedReplacePage;
  }

  void _changePPN({required int vpn, required int ppn}) {
    if (!_isValidVPN(vpn)) {
      debugPrint(
        "VPN ERROR: Attempt to access invalid PAGE TABLE ENTRY (VPN): [$vpn]",
      );
      return;
    }

    pageTable[vpn].ppn = ppn;
    pageTable[vpn].valid = true;
  }

  void _invalidateVPNEntry(int vpn) {
    if (!_isValidVPN(vpn)) {
      debugPrint(
        "VPN ERROR: Attempt to access invalid PAGE TABLE ENTRY (VPN): [$vpn]",
      );
      return;
    }

    pageTable[vpn].valid = false;
  }

  void resetMemory() {
    final config = Configuration.singleton;

    dynamic = List.generate(
      config.dynamicSizePages,
      (index) => DynamicMemoryPage.newPage,
    );

    pageTable = List.generate(
      config.pageTableSizeEntries,
      (index) => PageTableEntry.newEntry,
    );
  }
}
