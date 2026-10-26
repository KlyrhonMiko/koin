import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable wall clock for calendar boundaries and deterministic tests.
final calendarClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Refreshes date-dependent views at local midnight and after backgrounding.
class CalendarDayNotifier extends Notifier<DateTime> {
  Timer? _timer;
  bool _running = false;

  @override
  DateTime build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    final now = ref.watch(calendarClockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  void _schedule(DateTime now) {
    _timer?.cancel();
    // Calendar construction handles 23/25-hour days at DST boundaries.
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now), refresh);
  }

  void refresh() {
    final now = ref.read(calendarClockProvider)();
    final day = DateTime(now.year, now.month, now.day);
    if (state != day) {
      state = day;
    } else {
      // Same-day resume/refresh can cross a transaction's scheduled time.
      ref.notifyListeners();
    }
    if (_running) _schedule(now);
  }

  void start() {
    _running = true;
    refresh();
  }

  void suspend() {
    _running = false;
    _timer?.cancel();
  }
}

final calendarDayProvider = NotifierProvider<CalendarDayNotifier, DateTime>(
  CalendarDayNotifier.new,
);
