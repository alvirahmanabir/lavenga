import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Time source. Business rules (hold expiry, "past times", cancellation
/// windows) read this instead of DateTime.now() so they are testable.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}

class MockClock implements Clock {
  MockClock(this._now);
  DateTime _now;
  @override
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
  void set(DateTime t) => _now = t;
}

final clockProvider = Provider<Clock>((ref) => const SystemClock());
