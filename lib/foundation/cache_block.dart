class CacheBlock {
  bool valid;
  bool dirty;
  int tag;
  int latestAccess;

  CacheBlock({
    required this.dirty,
    required this.tag,
    required this.valid,
    required this.latestAccess,
  });

  static CacheBlock newBlock() =>
      CacheBlock(dirty: false, tag: 0, valid: false, latestAccess: 0);
}
