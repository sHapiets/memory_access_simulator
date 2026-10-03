class DynamicMemoryPage {
  bool used = false;
  int lastAccess = 0;

  DynamicMemoryPage({required this.used, required this.lastAccess});

  static DynamicMemoryPage newPage = DynamicMemoryPage(
    used: false,
    lastAccess: 0,
  );
}
