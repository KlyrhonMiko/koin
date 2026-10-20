import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/reports/report_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper.instance;
  final ledger = SqliteLedgerAdapter();
  late Directory directory;
  late Database db;
  final today = DateTime.now();

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_consistency_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await helper.database;
    await helper.insertAccount(
      Account(
        id: 'funded',
        name: 'Funded',
        initialBalance: 200,
        iconCodePoint: 0,
        colorHex: '#00D09E',
      ),
    );
    await helper.insertAccount(
      Account(
        id: 'empty',
        name: 'Empty',
        iconCodePoint: 0,
        colorHex: '#00D09E',
      ),
    );
  });
  tearDown(() async {
    await helper.close();
    await directory.delete(recursive: true);
  });

  PlannedPayment payment({
    double amount = 50,
    DateTime? start,
    DateTime? next,
  }) => PlannedPayment(
    id: 'schedule',
    title: 'Bill',
    amount: amount,
    type: TransactionType.expense,
    categoryId: 'cat_others',
    accountId: 'funded',
    startDate: start ?? DateTime(today.year, today.month, today.day),
    nextDate: next ?? DateTime(today.year, today.month, today.day),
    frequency: PaymentFrequency.monthly,
  );

  test(
    'scheduled invalid or unfunded amounts leave both schedule and ledger unchanged',
    () async {
      final schedule = payment();
      await helper.insertPlannedPayment(schedule);
      for (final amount in [0.0, -10.0, double.nan, 201.0]) {
        await expectLater(
          ledger.recordPlannedPaymentOccurrence(
            payment: schedule,
            amount: amount,
            accountId: 'funded',
            categoryId: 'cat_others',
          ),
          throwsA(isA<FinancialValidationException>()),
        );
      }
      expect(await ledger.getTransactions(), isEmpty);
      expect(
        (await helper.getPlannedPayments()).single.nextDate,
        schedule.nextDate,
      );
    },
  );

  test(
    'repayment receipt into an empty account is allowed; lending out is rejected',
    () async {
      final debt = Debt(
        id: 'iou',
        personName: 'Friend',
        amount: 100,
        type: DebtType.owedToMe,
        startDate: today,
      );
      await helper.insertDebt(debt);
      final incoming = await ledger.recordDebtRepayment(
        debt: debt,
        repayment: DebtRepayment(
          id: 'receipt',
          debtId: debt.id,
          amount: 50,
          date: today,
          accountId: 'empty',
        ),
        categoryId: 'cat_others_inc',
      );
      expect(incoming!.type, TransactionType.income);
      expect((await helper.getDebts()).single.currentAmount, 50);
      await expectLater(
        ledger.recordDebtRepayment(
          debt: debt,
          repayment: DebtRepayment(
            id: 'loan',
            debtId: debt.id,
            amount: 100,
            date: today,
            accountId: 'empty',
            isIncrease: true,
          ),
          categoryId: 'cat_others',
        ),
        throwsA(isA<FinancialValidationException>()),
      );
      expect((await helper.getDebts()).single.amount, 100);
    },
  );

  test('repayment IDs are idempotent and cannot apply twice', () async {
    final debt = Debt(
      id: 'debt',
      personName: 'Friend',
      amount: 100,
      type: DebtType.iOwe,
      startDate: today,
    );
    await helper.insertDebt(debt);
    final repayment = DebtRepayment(
      id: 'one',
      debtId: debt.id,
      amount: 25,
      date: today,
      accountId: 'funded',
    );
    await ledger.recordDebtRepayment(
      debt: debt,
      repayment: repayment,
      categoryId: 'cat_others',
    );
    await ledger.recordDebtRepayment(
      debt: debt,
      repayment: repayment,
      categoryId: 'cat_others',
    );
    expect((await helper.getDebts()).single.currentAmount, 25);
    expect(await ledger.getTransactions(), hasLength(1));
  });

  test('editing and deleting a transfer coordinates its one fee', () async {
    var draft = TransferDraft(
      sourceAccountId: 'funded',
      destinationAccountId: 'empty',
      rawAmount: 50,
      enteredFee: 5,
      date: today,
    );
    var built = draft.buildTransactions(existingId: 'transfer');
    await ledger.recordTransfer(
      transferTransaction: built.transferTransaction,
      feeTransaction: built.feeTransaction,
    );
    draft = TransferDraft(
      sourceAccountId: 'funded',
      destinationAccountId: 'empty',
      rawAmount: 60,
      enteredFee: 7,
      date: today,
    );
    built = draft.buildTransactions(existingId: 'transfer');
    await ledger.updateTransfer(
      built.transferTransaction,
      built.feeTransaction,
    );
    final records = await ledger.getTransactions();
    expect(records, hasLength(2));
    expect(records.singleWhere((tx) => tx.transferId == 'transfer').amount, 7);
    await ledger.voidTransaction('transfer');
    expect(await ledger.getTransactions(), isEmpty);
  });

  test(
    'deleting entities preserves history and clears all direct references',
    () async {
      await helper.insertTransaction(
        AppTransaction(
          id: 'history',
          amount: 20,
          date: today,
          type: TransactionType.income,
          accountId: 'funded',
          categoryId: 'cat_others_inc',
        ),
      );
      await helper.insertPlannedPayment(payment());
      await helper.deleteAccount('funded');
      expect((await helper.getTransactions()).single.accountId, '');
      expect((await helper.getPlannedPayments()).single.accountId, '');
      await helper.deleteCategory('cat_others_inc');
      expect((await helper.getTransactions()).single.categoryId, '');
    },
  );

  test(
    'month-end dates preserve their original anchor forward and backward',
    () {
      final schedule = payment(
        start: DateTime(2026, 1, 31),
        next: DateTime(2026, 1, 31),
      );
      expect(schedule.computeNextDate(), DateTime(2026, 2, 28));
      final february = schedule.copyWith(nextDate: schedule.computeNextDate());
      expect(february.computeNextDate(), DateTime(2026, 3, 31));
      expect(february.computePreviousDate(), DateTime(2026, 1, 31));
    },
  );

  test(
    'version 39 migration preserves history and links attributable transfer fees',
    () async {
      final built = TransferDraft(
        sourceAccountId: 'funded',
        destinationAccountId: 'empty',
        rawAmount: 20,
        enteredFee: 2,
        note: 'Bank',
        date: today,
      ).buildTransactions(existingId: 'legacy');
      await helper.insertTransaction(built.transferTransaction);
      await helper.insertTransaction(built.feeTransaction!);
      await db.execute('ALTER TABLE transactions DROP COLUMN transferId');
      await db.setVersion(39);
      await helper.close();
      db = await helper.database;
      expect(await db.getVersion(), 43);
      final records = await helper.getTransactions();
      expect(
        records
            .singleWhere((tx) => tx.type == TransactionType.expense)
            .transferId,
        'legacy',
      );
    },
  );

  test('upcoming omits expired schedules and future flexible income', () {
    final expired = payment().copyWith(
      endDate: today.subtract(const Duration(days: 1)),
    );
    final future = payment(
      start: today.add(const Duration(days: 10)),
    ).copyWith(id: 'future', frequency: PaymentFrequency.flexible);
    final afterEnd = payment().copyWith(
      id: 'after-end',
      nextDate: today.add(const Duration(days: 10)),
      endDate: today.add(const Duration(days: 2)),
    );
    expect(
      UpcomingTimeline.calculate(
        payments: [expired, future, afterEnd],
        debts: [],
        now: today,
      ).isEmpty,
      isTrue,
    );
  });

  test(
    'excluding account balance does not exclude spending history; future funds are not current',
    () {
      final account = Account(
        id: 'private',
        name: 'Private',
        initialBalance: 200,
        excludeFromTotal: true,
        iconCodePoint: 0,
        colorHex: '#00D09E',
      );
      final expense = AppTransaction(
        id: 'expense',
        amount: 20,
        date: today,
        type: TransactionType.expense,
        categoryId: 'cat_others',
        accountId: 'private',
      );
      final future = AppTransaction(
        id: 'future',
        amount: 100,
        date: today.add(const Duration(days: 2)),
        type: TransactionType.income,
        categoryId: 'cat_others_inc',
        accountId: 'private',
      );
      final stats = DashboardStats.calculate(
        accounts: [account],
        transactions: [expense, future],
      );
      expect(stats.totalExpense, 20);
      expect(stats.accountBalances['private'], 180);
      expect(stats.currentBalance, 0);
    },
  );

  test(
    'date filters include the complete first day regardless of supplied time',
    () {
      final day = DateTime(2026, 10, 1);
      final filter = TransactionFilter(
        dateRange: DateTimeRange(
          start: DateTime(2026, 10, 1, 15),
          end: DateTime(2026, 10, 2),
        ),
      );
      expect(
        filter.matches(
          AppTransaction(
            id: 'morning',
            amount: 1,
            date: day,
            type: TransactionType.expense,
            categoryId: '',
            accountId: '',
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'automatic due schedules process once and advance their persisted date',
    () async {
      await helper.insertPlannedPayment(
        payment().copyWith(isAutoProcess: true),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final automatic = container.read(automaticPaymentsProvider.notifier);
      await automatic.processDue(now: today);
      await automatic.processDue(now: today);
      expect(await ledger.getTransactions(), hasLength(1));
      expect(
        (await helper.getPlannedPayments()).single.nextDate.isAfter(today),
        isTrue,
      );
      expect(container.read(automaticPaymentsProvider).problems, isEmpty);
    },
  );

  test(
    'automatic expenses leave reserved savings intact and explain manual action',
    () async {
      await helper.insertPlannedPayment(
        payment().copyWith(isAutoProcess: true),
      );
      await helper.insertSavingsGoal(
        SavingsGoal(
          id: 'reserved',
          name: 'Reserved',
          currentAmount: 180,
          isStash: true,
          linkedAccountId: 'funded',
          startDate: today,
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(automaticPaymentsProvider.notifier)
          .processDue(now: today);
      expect(await ledger.getTransactions(), isEmpty);
      expect((await helper.getSavingsGoals()).single.currentAmount, 180);
      await expectLater(
        ledger.recordPlannedPaymentOccurrence(
          payment: (await helper.getPlannedPayments()).single,
          amount: 50,
          accountId: 'funded',
          categoryId: payment().categoryId,
          date: today,
          protectSavings: true,
        ),
        throwsA(isA<FinancialValidationException>()),
      );
      expect(await ledger.getTransactions(), isEmpty);
      expect(
        container.read(automaticPaymentsProvider).problems.single,
        contains('savings'),
      );
    },
  );

  test(
    'CSV declares currency and PDF tolerates transfers with missing identities',
    () async {
      final transfer = AppTransaction(
        id: 'transfer',
        amount: 10,
        date: today,
        type: TransactionType.transfer,
        categoryId: '',
        accountId: '',
        toAccountId: 'removed',
      );
      final csv = await ReportService.generateReport(
        transactions: [transfer],
        categories: [],
        accounts: [],
        currencySymbol: '¥',
        currencyCode: 'CNY',
        isPdf: false,
      );
      expect(utf8.decode(csv.bytes), contains('Currency'));
      expect(utf8.decode(csv.bytes), contains('CNY'));
      final pdf = await ReportService.generateReport(
        transactions: [transfer],
        categories: [],
        accounts: [],
        currencySymbol: '¥',
        currencyCode: 'CNY',
        isPdf: true,
      );
      expect(pdf.bytes.take(4), '%PDF'.codeUnits);
    },
  );
}
