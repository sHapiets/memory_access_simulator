import 'package:flutter/cupertino.dart';
import 'package:memory_access_simulator/foundation/access.dart';

class AccessSequence extends ChangeNotifier {
  AccessSequence._() {
    reset();
  }

  static final singleton = AccessSequence._();

  List<Access> sequence = [];
  int pointer = -1;

  void reset() {
    sequence = [];
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
}
