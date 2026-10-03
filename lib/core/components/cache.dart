import 'package:flutter/cupertino.dart';
import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';
import 'package:memory_access_simulator/foundation/cache_block.dart';
import 'package:memory_access_simulator/foundation/parser.dart';

class Cache {
  Cache._() {
    resetCache();
  }
  static final singleton = Cache._();

  List<CacheBlock> blocks = [];

  void resetCache() {
    final config = Configuration.singleton;
    blocks = List.generate(
      config.cacheSizeBlocks,
      (int index) => CacheBlock.newBlock(),
    );
  }

  bool isCacheLineValid(int lineNumber) => blocks[lineNumber].valid;

  int getCacheLine(int address) {
    final config = Configuration.singleton;
    int tag = Parser.cacheTagFromAddress(
      address,
      config.blockSizeBytes,
      config.cacheSets,
    );
    int index = Parser.cacheIndexFromAddress(
      address,
      config.blockSizeBytes,
      config.cacheSets,
    );

    int startLine = index * config.cacheSetSizeBlocks;
    int endLine = startLine + config.cacheSetSizeBlocks - 1;

    for (int i = startLine; i <= endLine; i++) {
      final cacheLine = blocks[i];

      if (cacheLine.valid && cacheLine.tag == tag) {
        return i;
      }
    }

    return -1;
  }

  int loadBlockFromMemory(int address) {
    final config = Configuration.singleton;
    int tag = Parser.cacheTagFromAddress(
      address,
      config.blockSizeBytes,
      config.cacheSets,
    );
    int index = Parser.cacheIndexFromAddress(
      address,
      config.blockSizeBytes,
      config.cacheSets,
    );

    int startLine = index * config.cacheSetSizeBlocks;
    int endLine = startLine + config.cacheSetSizeBlocks - 1;

    int selectedCacheLine = startLine;
    int selectedLatestAccess = blocks[startLine].latestAccess;

    bool isValidLineReplaced = true;

    for (int i = startLine; i <= endLine; i++) {
      final cacheLine = blocks[i];

      if (!cacheLine.valid) {
        selectedCacheLine = i;
        isValidLineReplaced = false;
        break;
      }

      if (selectedLatestAccess > cacheLine.latestAccess) {
        selectedCacheLine = i;
        selectedLatestAccess = cacheLine.latestAccess;
      }
    }

    if (!_isCacheLineOutOfBounds(selectedCacheLine)) {
      debugPrint(
        "CACHE ERROR: Attempt to access invalid CACHE LINE: Line [$selectedCacheLine]",
      );
      return -1;
    }

    if (isValidLineReplaced && blocks[selectedCacheLine].dirty) {
      // TODO: Writeback to DRAM Stats / Delay
    }

    blocks[selectedCacheLine].tag = tag;
    blocks[selectedCacheLine].valid = true;

    return selectedCacheLine;
  }

  void accessCacheLine(
    int lineNumber,
    AccessType accessType,
    int accessNumber,
  ) {
    if (!_isCacheLineOutOfBounds(lineNumber)) {
      debugPrint(
        "CACHE ERROR: Attempt to access invalid CACHE LINE: Line [$lineNumber]",
      );
      return;
    }

    if (accessType == AccessType.store) _dirtyCacheLine(lineNumber);
    blocks[lineNumber].latestAccess = accessNumber;
  }

  void invalidateCacheLineFromPageNumber(int ppn) {
    final config = Configuration.singleton;

    for (int i = 0; i <= blocks.length; i++) {
      final cacheLine = blocks[i];

      final int cacheLinePPN = cacheLine.tag >> config.pageBlockOffsetBits;
      if (cacheLinePPN == ppn) {
        // TODO: If dirty, writeback delay (?>
        blocks[i].valid = false;
      }
    }
  }

  void _dirtyCacheLine(int lineNumber) {
    if (!_isCacheLineOutOfBounds(lineNumber)) {
      debugPrint(
        "CACHE ERROR: Attempt to access invalid CACHE LINE: Line [$lineNumber]",
      );
      return;
    }

    blocks[lineNumber].dirty = true;
  }

  bool _isCacheLineOutOfBounds(int lineNumber) =>
      blocks.length > lineNumber && lineNumber >= 0;
}
