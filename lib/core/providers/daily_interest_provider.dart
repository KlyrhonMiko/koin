import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/daily_interest_repository.dart';
import 'category_provider.dart';
import 'settings_provider.dart';
import 'transaction_provider.dart';

/// Accrues interest and posts due payouts at launch, resume, and across midnight.
class DailyInterestNotifier extends Notifier<AsyncValue<int>> {
  Timer? _timer;
  Future<int>? _pending;
  bool _disposed = false;

  @override
  AsyncValue<int> build() {
    ref.onDispose(() {
      _disposed = true;
      stop();
    });
    return const AsyncData(0);
  }

  void start() {
    stop();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    unawaited(_tick());
  }

  void stop() => _timer?.cancel();

  Future<void> _tick() async {
    try {
      await processDue();
    } catch (_) {
      // Retain the error for the account editor; retry on the next tick/resume.
    }
  }

  Future<int> processDue({DateTime? now}) =>
      _pending ??= _process(now ?? DateTime.now())
          .whenComplete(() => _pending = null);

  Future<int> _process(DateTime now) async {
    try {
      final count = await ref
          .read(dailyInterestRepositoryProvider)
          .processDue(
            now: now,
            decimalDigits: ref.read(settingsProvider).currency.decimalDigits,
          );
      if (!_disposed) {
        if (count > 0) {
          ref.invalidate(transactionProvider);
          ref.invalidate(categoriesProvider);
        }
        state = AsyncData(count);
      }
      return count;
    } catch (error, stack) {
      if (!_disposed) state = AsyncError(error, stack);
      rethrow;
    }
  }
}

final dailyInterestProvider =
    NotifierProvider<DailyInterestNotifier, AsyncValue<int>>(
      DailyInterestNotifier.new,
    );
