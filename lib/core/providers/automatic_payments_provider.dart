import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ledger/ledger.dart';
import '../ledger/transaction_rules.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'providers.dart';

class AutomaticPaymentsState {
  const AutomaticPaymentsState({
    this.busy = false,
    this.processed = 0,
    this.problems = const [],
  });
  final bool busy;
  final int processed;
  final List<String> problems;
}

/// Due schedules run while Koin is open and immediately when it resumes.
/// Automatic expenses never release reserved savings without confirmation.
class AutomaticPaymentsNotifier extends Notifier<AutomaticPaymentsState> {
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;
  @override
  AutomaticPaymentsState build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    return const AutomaticPaymentsState();
  }

  void start() {
    stop();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(processDue()),
    );
    unawaited(processDue());
  }

  void stop() => _timer?.cancel();

  Future<void> processDue({DateTime? now}) async {
    if (_running || _disposed) return;
    _running = true;
    state = AutomaticPaymentsState(
      busy: true,
      processed: state.processed,
      problems: state.problems,
    );
    var count = 0;
    final problems = <String>[];
    try {
      final at = now ?? DateTime.now();
      final repository = ref.read(plannedPaymentRepositoryProvider);
      final ledger = ref.read(ledgerProvider);
      final payments = await repository.getPlannedPayments();
      for (var payment in payments) {
        if (!payment.isAutoProcess ||
            payment.frequency == PaymentFrequency.flexible ||
            !payment.isEligible(at)) {
          continue;
        }
        var occurrences = 0;
        while (payment.daysUntilNext(at) <= 0 && occurrences < 100) {
          try {
            final accounts = await ref
                .read(accountRepositoryProvider)
                .getAccounts();
            final transactions = await ledger.getTransactions();
            TransactionRules.account(
              accountId: payment.accountId,
              value: payment.amount,
              isExpense: payment.type == TransactionType.expense,
              accounts: accounts,
              transactions: transactions,
              at: at,
            );
            final account = accounts.firstWhere(
              (a) => a.id == payment.accountId,
            );
            if (payment.type == TransactionType.expense && !account.isCredit) {
              final goals = await ref
                  .read(savingsRepositoryProvider)
                  .getSavingsGoals();
              final reserved = goals
                  .where((g) => g.linkedAccountId == account.id)
                  .fold<double>(0, (sum, g) => sum + g.currentAmount);
              if (TransactionRules.balance(account, transactions, at: at) -
                      reserved <
                  payment.amount) {
                throw const FinancialValidationException(
                  'Open this payment to review the savings needed.',
                );
              }
            }
            await ledger.recordPlannedPaymentOccurrence(
              payment: payment,
              amount: payment.amount,
              accountId: payment.accountId,
              categoryId: payment.categoryId,
              date: at,
              protectSavings: true,
            );
            payment = payment.copyWith(nextDate: payment.computeNextDate());
            count++;
            occurrences++;
          } catch (error) {
            problems.add(
              '${payment.title}: ${error is FinancialValidationException ? error.message : 'Could not process. Try again.'}',
            );
            break;
          }
        }
      }
    } catch (_) {
      problems.add('Could not load automatic schedules. Try again.');
    } finally {
      _running = false;
      if (!_disposed) {
        if (count > 0) {
          ref.invalidate(plannedPaymentProvider);
          ref.invalidate(transactionProvider);
        }
        state = AutomaticPaymentsState(
          processed: state.processed + count,
          problems: problems,
        );
      }
    }
  }
}

final automaticPaymentsProvider =
    NotifierProvider<AutomaticPaymentsNotifier, AutomaticPaymentsState>(
      AutomaticPaymentsNotifier.new,
    );
