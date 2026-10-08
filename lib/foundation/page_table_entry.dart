class PageTableEntry {
  bool valid;
  bool dirty;
  int ppn;

  PageTableEntry({required this.valid, required this.dirty, required this.ppn});

  static PageTableEntry newEntry() {
    return PageTableEntry(valid: false, dirty: false, ppn: 0);
  }
}
