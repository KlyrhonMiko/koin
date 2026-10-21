import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_provider.dart';

import 'package:koin/core/models/models.dart';
import 'package:koin/core/ledger/ledger.dart';
import 'package:koin/core/repositories/planned_payment_repository.dart';
import 'package:koin/core/providers/transaction_provider.dart';

import 'package:koin/core/providers/debt_provider.dart';

class PlannedPaymentNotifier extends AsyncNotifier<List<PlannedPayment>> {
  PlannedPaymentRepository get _repository =>
      ref.read(plannedPaymentRepositoryProvider);

  @override
  Future<List<PlannedPayment>> build() async {
    return await _repository.getPlannedPayments();
  }

  Future<void> loadPlannedPayments() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _repository.getPlannedPayments();
    });
  }

  Future<void> addPlannedPayment(PlannedPayment payment) async {
    await _repository.insertPlannedPayment(payment);
    await loadPlannedPayments();
  }

  Future<void> updatePlannedPayment(PlannedPayment payment) async {
    await _repository.updatePlannedPayment(payment);
    await loadPlannedPayments();
  }

  Future<void> deletePlannedPayment(String id) async {
    await _repository.deletePlannedPayment(id);
    await loadPlannedPayments();
  }

  /// Atomically processes a planned payment occurrence through the Ledger seam,
  /// updating the schedule forward and recording the resulting financial transaction.
  Future<AppTransaction> processOccurrence({
    required PlannedPayment payment,
    required double amount,
    required String accountId,
    required String categoryId,
    String? transactionId,
    DateTime? date,
  }) async {
    final ledger = ref.read(ledgerProvider);
    final tx = await ledger.recordPlannedPaymentOccurrence(
      payment: payment,
      amount: amount,
      accountId: accountId,
      categoryId: categoryId,
      transactionId: transactionId,
      date: date,
    );
    await loadPlannedPayments();
    ref.invalidate(transactionProvider);
    return tx;
  }
}

final plannedPaymentProvider =
    AsyncNotifierProvider<PlannedPaymentNotifier, List<PlannedPayment>>(() {
      return PlannedPaymentNotifier();
    });

final upcomingTimelineProvider = Provider<AsyncValue<UpcomingTimeline>>((ref) {
  ref.watch(calendarDayProvider);
  final payments = ref.watch(plannedPaymentProvider);
  final debts = ref.watch(debtsProvider);
  // A partial or failed source must never look like a complete empty timeline.
  if (payments.hasError) {
    return AsyncError(payments.error!, payments.stackTrace!);
  }
  if (debts.hasError) {
    return AsyncError(debts.error!, debts.stackTrace!);
  }
  if (payments.isLoading ||
      debts.isLoading ||
      !payments.hasValue ||
      !debts.hasValue) {
    return const AsyncLoading();
  }
  return AsyncData(
    UpcomingTimeline.calculate(
      payments: payments.value!,
      debts: debts.value!,
      now: ref.read(calendarClockProvider)(),
    ),
  );
});

void retryUpcoming(WidgetRef ref) {
  ref.invalidate(plannedPaymentProvider);
  ref.invalidate(debtsProvider);
}
