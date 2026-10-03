class TLBEntry {
  int vpn;
  bool valid;
  int ppn;
  int lastAccess;

  TLBEntry({
    required this.vpn,
    required this.valid,
    required this.ppn,
    required this.lastAccess,
  });

  static TLBEntry newEntry = TLBEntry(
    vpn: 0,
    valid: false,
    ppn: 0,
    lastAccess: 0,
  );
}
