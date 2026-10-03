import 'dart:math';

class Parser {
  static int pageNumberFromAddress(int address, int pageSizeBytes) {
    int offsetBits = log(pageSizeBytes) / ln2 as int;

    return address >> offsetBits;
  }

  static int pageOffsetFromAddress(int address, int pageSizeBytes) {
    return address & (pageSizeBytes - 1);
  }

  static int addressFromPageComponents(
    int pageNumber,
    int pageOffset,
    int pageSizeBytes,
  ) {
    int offsetBits = log(pageSizeBytes) / ln2 as int;
    int completeAddress = pageNumber << offsetBits;
    return completeAddress + pageOffset;
  }

  static int cacheTagFromAddress(
    int address,
    int blockSizeBytes,
    int cacheSets,
  ) {
    int indexBits = log(cacheSets) / ln2 as int;
    int offsetBits = log(blockSizeBytes) / ln2 as int;

    return address >> (indexBits + offsetBits);
  }

  static int cacheIndexFromAddress(
    int address,
    int blockSizeBytes,
    int cacheSets,
  ) {
    int offsetBits = log(blockSizeBytes) / ln2 as int;

    return (address >> offsetBits) & (cacheSets - 1);
  }

  static int cacheOffsetFromAddress(int address, int blockSizeBytes) {
    return address & (blockSizeBytes - 1);
  }
}
