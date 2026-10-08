enum MicroStep {
  initialize,
  tlb,
  pageTable,
  pageFaultEviction,
  pageFaultLoad,
  cache,
  dram,
  complete,
}
