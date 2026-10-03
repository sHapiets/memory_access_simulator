import 'package:memory_access_simulator/foundation/access.dart';

class AccessSequence {
  AccessSequence._() {
    reset();
  }
  static final singleton = AccessSequence._();

  List<Access> sequence = [];
  int pointer = 0;

  void reset() {
    sequence = [];
    pointer = 0;
  }
}
