import 'package:memory_access_simulator/foundation/access_type.dart';

class Access {
  AccessType type;
  int address;

  Access({required this.type, required this.address});
}
