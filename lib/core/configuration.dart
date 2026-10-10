import 'dart:math';

class Configuration {
  Configuration._();
  static final singleton = Configuration._();

  /// General
  int blockSizeBytes = 16;
  int pageSizeBlocks = 4;
  int get pageSizeBytes => pageSizeBlocks * blockSizeBytes;

  int get blockOffsetBits => log(blockSizeBytes) / ln2 as int;
  int get pageOffsetBits => log(pageSizeBytes) / ln2 as int;
  int get pageBlockOffsetBits => pageOffsetBits - blockOffsetBits;

  /// Cache
  int cacheSizeBlocks = 4;
  int cacheSets = 2;
  int get cacheSetSizeBlocks => (cacheSizeBlocks / cacheSets) as int;
  int get cacheIndexBits => log(cacheSets) / ln2 as int;

  // TLB
  int tlbSize = 4;

  /// DRAM
  int dynamicSizePages = 16;
  int get ppnBits => log(dynamicSizePages) / ln2 as int;

  /// Page Table
  int vpnBits = 5;
  int get pageTableSizeEntries => pow(2, vpnBits) as int;

  void saveConfig() {}
}
