class Connection {
  int microStepNumber = -1;
  bool active = false;

  Connection({required this.active, required this.microStepNumber});

  void set(Connection newConnection) {
    microStepNumber = newConnection.microStepNumber;
    active = newConnection.active;
  }

  void setActive(int microStepNumber) {
    active = true;
    this.microStepNumber = microStepNumber;
  }

  void setInactiveOnly() {
    active = false;
  }

  void reset() {
    microStepNumber = -1;
    active = false;
  }

  static Connection newConnection() {
    return Connection(active: false, microStepNumber: -1);
  }
}
