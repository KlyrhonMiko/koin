import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_provider.dart';
import 'transaction_provider.dart';

/// Wake exactly when the next recorded transaction becomes effective.
/// Calendar refresh/resume and transaction changes reschedule the boundary.
final effectiveTransactionClockProvider = Provider<DateTime>((ref) {
  ref.watch(calendarDayProvider);
  final now = ref.watch(calendarClockProvider)();
  final transactions = ref.watch(transactionProvider).value ?? [];
  DateTime? next;
  for (final transaction in transactions) {
    if (transaction.date.isAfter(now) &&
        (next == null || transaction.date.isBefore(next))) {
      next = transaction.date;
    }
  }
  if (next != null) {
    final timer = Timer(next.difference(now), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return now;
});
