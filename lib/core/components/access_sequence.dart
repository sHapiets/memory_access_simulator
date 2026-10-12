import 'package:flutter/cupertino.dart';
import 'package:memory_access_simulator/foundation/access.dart';
import 'package:memory_access_simulator/foundation/access_type.dart';

class AccessSequence extends ChangeNotifier {
  AccessSequence._() {
    reset();
  }

  static final singleton = AccessSequence._();

  List<Access> sequence = [];
  int pointer = -1;

  void restart() {
    pointer = -1;
    notifyListeners();
  }

  void reset() {
    sequence = [
      // ============================================================
      // Page 0 — initial page fault, TLB miss, cache miss
      // ============================================================
      Access(
        type: AccessType.load,
        address: 0,
      ), // Page fault, TLB miss, cache miss
      Access(type: AccessType.load, address: 0), // TLB hit, cache hit
      Access(type: AccessType.store, address: 4), // TLB hit, cache hit
      Access(type: AccessType.load, address: 16), // TLB hit, cache miss
      // ============================================================
      // Page 1 — new page, another page fault
      // ============================================================
      Access(
        type: AccessType.load,
        address: 64,
      ), // Page fault, TLB miss, cache miss
      Access(type: AccessType.load, address: 64), // TLB hit, cache hit
      Access(type: AccessType.load, address: 68), // TLB hit, cache hit
      Access(type: AccessType.load, address: 80), // TLB hit, cache miss
      // ============================================================
      // Page 2 — new page, another page fault
      // ============================================================
      Access(
        type: AccessType.load,
        address: 128,
      ), // Page fault, TLB miss, cache miss
      Access(type: AccessType.load, address: 128), // TLB hit, cache hit
      Access(type: AccessType.store, address: 132), // TLB hit, cache hit
      // ============================================================
      // Page 0 revisited — should now be resident
      // ============================================================
      Access(
        type: AccessType.load,
        address: 0,
      ), // TLB hit if still resident; cache hit/miss depends on replacement
      // ============================================================
      // Page 3 — another new page
      // ============================================================
      Access(
        type: AccessType.load,
        address: 192,
      ), // Page fault, TLB miss, cache miss
      Access(type: AccessType.load, address: 192), // TLB hit, cache hit
      // ============================================================
      // Page 4 — TLB pressure (TLB holds 4 entries)
      // ============================================================
      Access(
        type: AccessType.load,
        address: 256,
      ), // Page fault, TLB miss, cache miss
      Access(type: AccessType.load, address: 256), // TLB hit, cache hit
      // ============================================================
      // Return to page 0 — may cause TLB miss after eviction
      // ============================================================
      Access(type: AccessType.load, address: 0),

      // ============================================================
      // Cache conflict testing
      // Blocks 0, 2, and 4 map to the same cache set
      // ============================================================
      Access(type: AccessType.load, address: 0),
      Access(type: AccessType.load, address: 32),
      Access(type: AccessType.load, address: 64),
      Access(type: AccessType.load, address: 0),
    ];
    pointer = -1;
    notifyListeners();
  }

  void setSequence(List<Access> newSequence) {
    sequence = newSequence;
    pointer = -1;
    notifyListeners();
  }

  void advance() {
    if (pointer < sequence.length - 1) {
      pointer++;
      notifyListeners();
    }
  }

  void restoreSnapshot({required List<Access> sequence, required int pointer}) {
    this.sequence = sequence
        .map((access) => Access(type: access.type, address: access.address))
        .toList();

    this.pointer = pointer;
    notifyListeners();
  }
}
