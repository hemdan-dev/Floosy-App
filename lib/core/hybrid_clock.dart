class HybridClock {
  HybridClock(this.deviceId, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final String deviceId;
  final DateTime Function() _now;
  int _lastMillis = 0;
  int _counter = 0;

  String tick([String? observed]) {
    if (observed != null) observe(observed);
    final current = _now().toUtc().millisecondsSinceEpoch;
    if (current > _lastMillis) {
      _lastMillis = current;
      _counter = 0;
    } else {
      _counter++;
    }
    return '$_lastMillis-$_counter-$deviceId';
  }

  void observe(String stamp) {
    final parts = stamp.split('-');
    if (parts.length < 3) return;
    final millis = int.tryParse(parts[0]);
    final counter = int.tryParse(parts[1]);
    if (millis == null || counter == null) return;
    if (millis > _lastMillis) {
      _lastMillis = millis;
      _counter = counter;
    } else if (millis == _lastMillis && counter > _counter) {
      _counter = counter;
    }
  }

  static int compare(String a, String b) {
    final aa = a.split('-');
    final bb = b.split('-');
    if (aa.length < 3 || bb.length < 3) return a.compareTo(b);
    final millis = int.parse(aa[0]).compareTo(int.parse(bb[0]));
    if (millis != 0) return millis;
    final counter = int.parse(aa[1]).compareTo(int.parse(bb[1]));
    if (counter != 0) return counter;
    return aa.sublist(2).join('-').compareTo(bb.sublist(2).join('-'));
  }
}
