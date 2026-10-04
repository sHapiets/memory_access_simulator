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

  int findFreeCacheLine(int address) {
    final config = Configuration.singleton;
    int index = Parser.cacheIndexFromAddress(
      address,
      config.blockSizeBytes,
      config.cacheSets,
    );

    int startLine = index * config.cacheSetSizeBlocks;
    int endLine = startLine + config.cacheSetSizeBlocks - 1;

    for (int i = startLine; i <= endLine; i++) {
      final cacheLine = blocks[i];

      if (!cacheLine.valid) {
        return i;
      }
    }

    return -1;
  }

  int findReplaceCacheLine(int address) {
    final config = Configuration.singleton;
    int index = Parser.cacheIndexFromAddress(
      address,
      config.blockSizeBytes,
      config.cacheSets,
    );

    int startLine = index * config.cacheSetSizeBlocks;
    int endLine = startLine + config.cacheSetSizeBlocks - 1;

    int selectedCacheLine = startLine;
    int selectedLatestAccess = blocks[startLine].latestAccess;

    for (int i = startLine; i <= endLine; i++) {
      final cacheLine = blocks[i];

      if (selectedLatestAccess > cacheLine.latestAccess) {
        selectedCacheLine = i;
        selectedLatestAccess = cacheLine.latestAccess;
      }
    }

    return selectedCacheLine;
  }

  int loadBlockFromMemory(int lineNumber, int address) {
    final config = Configuration.singleton;
    int tag = Parser.cacheTagFromAddress(
      address,
      config.blockSizeBytes,
      config.cacheSets,
    );

    int replacedLinePPN = -1;

    if (blocks[lineNumber].dirty && blocks[lineNumber].valid) {
      // TODO: Writeback to DRAM Stats / Delay
      final int replacedLineIndex = lineNumber ~/ config.cacheSetSizeBlocks;
      int replacedLineBlockAddress =
          (blocks[lineNumber].tag << config.cacheIndexBits) + replacedLineIndex;
      replacedLinePPN = replacedLineBlockAddress >> config.pageBlockOffsetBits;
    }

    blocks[lineNumber].tag = tag;
    blocks[lineNumber].valid = true;
    blocks[lineNumber].dirty = false;

    return replacedLinePPN;
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

  bool invalidateCacheLineFromPPN(int ppn) {
    bool dirty = false;

    final config = Configuration.singleton;

    for (int i = 0; i < blocks.length; i++) {
      final cacheLine = blocks[i];

      if (!cacheLine.valid) continue;

      final int cacheIndex = i ~/ config.cacheSetSizeBlocks;
      int blockAddress = (cacheLine.tag << config.cacheIndexBits) + cacheIndex;
      final int cacheLinePPN = blockAddress >> config.pageBlockOffsetBits;
      if (cacheLinePPN == ppn) {
        if (blocks[i].dirty) {
          // TODO: If dirty, writeback delay (?>
          dirty = true;
        }
        blocks[i].valid = false;
      }
    }

    return dirty;
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
