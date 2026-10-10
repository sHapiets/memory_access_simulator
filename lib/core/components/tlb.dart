import 'package:memory_access_simulator/core/configuration.dart';
import 'package:memory_access_simulator/foundation/tlb_entry.dart';

class TLB {
  TLB._() {
    resetTLB();
  }
  static final singleton = TLB._();

  List<TLBEntry> entries = [];

  void resetTLB() {
    final config = Configuration.singleton;
    entries = List.generate(config.tlbSize, (index) => TLBEntry.newEntry());
  }

  int getPPN(int vpn) {
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.valid && entry.vpn == vpn) {
        return entry.ppn;
      }
    }

    return -1;
  }

  void invalidateEntry(int vpn) {
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.valid && entry.vpn == vpn) {
        entries[i].valid = false;
      }
    }
  }

  int accessEntry(int vpn, int accessNumber) {
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.valid && entry.vpn == vpn) {
        entries[i].lastAccess = accessNumber;
        return i;
      }
    }

    return -1;
  }

  int addEntry(int vpn, int ppn, int currentAccessNumber) {
    final newEntry = TLBEntry(
      vpn: vpn,
      valid: true,
      ppn: ppn,
      lastAccess: currentAccessNumber,
    );
    int selectedEntry = 0;
    int selectedLatestAccess = entries[0].lastAccess;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (!entry.valid) {
        entries[i] = newEntry;
        return i;
      }

      if (selectedLatestAccess > entry.lastAccess) {
        selectedEntry = i;
        selectedLatestAccess = entry.lastAccess;
      }
    }

    entries[selectedEntry] = newEntry;
    return selectedEntry;
  }
}
