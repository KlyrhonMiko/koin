import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/widgets/savings_plan_editor.dart';
import 'package:koin/features/savings/widgets/savings_log_sheet.dart';
import 'package:koin/features/debts/widgets/add_repayment_sheet.dart';
import 'package:koin/features/budgets/widgets/budget_editor_sheet.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/features/dashboard/widgets/upcoming_entry_tile.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Outfit');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      loader.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await loader.load();
  });
  final now = DateTime(2026, 10, 30);
  final account = Account(
    id: 'cash',
    name: 'Cash',
    initialBalance: 50000,
    iconCodePoint: KoinIcons.wallet.codePoint,
    colorHex: '#00D09E',
  );
  final category = TransactionCategory(
    id: 'food',
    name: 'Food',
    type: TransactionType.expense,
    iconCodePoint: KoinIcons.forkKnife.codePoint,
    colorHex: '#F59E0B',
    budget: 10000,
  );
  final debt = Debt(
    id: 'debt',
    personName: 'Alex',
    amount: 12000,
    currentAmount: 3000,
    type: DebtType.iOwe,
    startDate: now,
    totalInstallments: 6,
  );
  final goal = SavingsGoal(
    id: 'goal',
    name: 'Emergency fund',
    currentAmount: 1000,
    startDate: now,
    linkedAccountId: 'cash',
  );
  final payment = PlannedPayment(
    id: 'rent',
    title: 'Monthly rent',
    amount: 8000,
    type: TransactionType.expense,
    categoryId: 'food',
    accountId: 'cash',
    startDate: now,
    nextDate: now,
    frequency: PaymentFrequency.monthly,
  );

  Future<ProviderContainer> mount(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'currency_code': 'PHP',
      'setup_completed': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(initial: [account]),
        ),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(initial: [category]),
        ),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(
            initial: [
              AppTransaction(
                id: 'tx',
                amount: 150,
                date: now,
                accountId: 'cash',
                categoryId: 'food',
                type: TransactionType.expense,
                note: 'Lunch',
              ),
            ],
          ),
        ),
        savingsRepositoryProvider.overrideWithValue(
          InMemorySavingsAdapter(initial: [goal]),
        ),
        debtRepositoryProvider.overrideWithValue(
          InMemoryDebtAdapter(initial: [debt]),
        ),
        plannedPaymentRepositoryProvider.overrideWithValue(
          InMemoryPlannedPaymentAdapter(initial: [payment]),
        ),
        categorySuggesterProvider.overrideWithValue(TestStubSuggesterAdapter()),
      ],
    );
    addTearDown(c.dispose);
    await Future.wait([
      c.read(accountProvider.future),
      c.read(transactionProvider.future),
      c.read(categoriesProvider.future),
      c.read(savingsGoalsProvider.future),
      c.read(debtsProvider.future),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), false),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('savings plan saves a grouped amount using the validated value', (
    tester,
  ) async {
    SavingsPlanEditResult? result;
    await mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await SavingsPlanEditor.open(context);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan_amount')), '1,000');
    await tester.pump();
    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result?.plan?.amount, 1000);
  });

  testWidgets(
    'payment failure retains the edited draft and pending save blocks Back',
    (tester) async {
      final gate = Completer<bool>();
      var calls = 0;
      PaymentConfirmationResult? saved;
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await PaymentConfirmationSheet.show(
                  context: context,
                  payment: payment,
                  onConfirm: (_, draft) async {
                    calls++;
                    if (calls == 1) throw StateError('write failed');
                    return gate.future;
                  },
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.ensureVisible(find.text('Confirm payment'));
      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentConfirmationSheet), findsOneWidget);
      expect(saved, isNull);
      expect(find.text('9'), findsNWidgets(2));
      await tester.tap(find.text('Confirm payment'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PaymentConfirmationSheet), findsOneWidget);
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(saved?.amount, 9);
      expect(find.byType(PaymentConfirmationSheet), findsNothing);
    },
  );

  testWidgets('repayment Back confirms discard and Cancel keeps the note', (
    tester,
  ) async {
    await mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AddRepaymentSheet.show(context, debt: debt),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Keep this note');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard repayment changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this note'), findsOneWidget);
    expect(find.byType(AddRepaymentSheet), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 1.8, 2.0]) {
    testWidgets('numpad confirmation stays one line at $scale text scale', (
      tester,
    ) async {
      var submitted = false;
      await mount(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: NumPad(
              compact: true,
              doneLabel: 'Confirm payment',
              initialValue: '100',
              onValueChanged: (_, _) {},
              onDone: () => submitted = true,
            ),
          ),
        ),
        size: const Size(320, 640),
        scale: scale,
      );
      final semantics = tester.ensureSemantics();
      final key = find.bySemanticsLabel('Confirm payment');
      expect(tester.getSize(key).width, lessThan(320 * .6));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Confirm payment'),
      );
      expect(
        paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 15),
        ),
        hasLength(1),
      );
      expect(
        tester.getRect(find.text('Confirm payment')).width,
        lessThanOrEqualTo(tester.getSize(key).width),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(key);
      await tester.pumpAndSettle();
      expect(submitted, isTrue);
      semantics.dispose();
    });
  }

  for (final variant in [
    (const Size(390, 844), 1.0, 330.0),
    (const Size(320, 640), 1.8, 300.0),
    (const Size(640, 360), 1.0, 160.0),
  ]) {
    testWidgets(
      'repayment confirm stays fully above keyboard at ${variant.$1}',
      (tester) async {
        await mount(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => AddRepaymentSheet.show(context, debt: debt),
                child: const Text('Open'),
              ),
            ),
          ),
          size: variant.$1,
          scale: variant.$2,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Keep this note');
        tester.view.viewInsets = FakeViewPadding(bottom: variant.$3);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final button = find.widgetWithText(ElevatedButton, 'Confirm Payment');
        final buttonRect = tester.getRect(button);
        final labelRect = tester.getRect(find.text('Confirm Payment'));
        expect(
          buttonRect.bottom,
          lessThanOrEqualTo(variant.$1.height - variant.$3 - 12),
        );
        expect(buttonRect.top, greaterThanOrEqualTo(0));
        expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
        expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('Keep this note'), findsOneWidget);
      },
    );
  }

  for (final variant in [
    (const Size(320, 640), 1.8),
    (const Size(640, 360), 1.0),
  ]) {
    for (final sheet in [
      'repayment',
      'increase',
      'budget',
      'savings',
      'scheduled',
    ]) {
      testWidgets('$sheet stays usable in ${variant.$1} at ${variant.$2}', (
        tester,
      ) async {
        final widget = switch (sheet) {
          'repayment' => AddRepaymentSheet(debt: debt),
          'increase' => AddRepaymentSheet(debt: debt, isIncrease: true),
          'budget' => BudgetEditorSheet(
            category: category,
            currency: Currency.defaultCurrency,
            totalIncome: 30000,
          ),
          'savings' => SavingsLogSheet(
            goal: goal,
            linkedAccount: account,
            linkedBalance: 50000,
            onSave: (_) async {},
          ),
          _ => PaymentConfirmationSheet(payment: payment),
        };
        await mount(
          tester,
          Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: widget),
          ),
          size: variant.$1,
          scale: variant.$2,
        );
        expect(tester.takeException(), isNull);
        final action = sheet == 'repayment' || sheet == 'scheduled'
            ? 'Confirm payment'
            : sheet == 'increase'
            ? 'Confirm increase'
            : 'Save';
        await tester.ensureVisible(find.text(action));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(action).hitTestable(), findsOneWidget);
      });
    }
  }

  for (final variant in [(false, false), (true, false), (false, true)]) {
    final (large, longAmount) = variant;
    final value = longAmount ? 1234567890123.45 : 200.0;
    testWidgets(
      'upcoming amount alignment and readable layout: large=$large longAmount=$longAmount',
      (tester) async {
        final allowance = payment.copyWith(
          title: 'Allowance',
          amount: value,
          type: TransactionType.income,
          frequency: PaymentFrequency.flexible,
        );
        final currency = Currency.defaultCurrency;
        var opened = false;
        await mount(
          tester,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                UpcomingEntryTile(
                  margin: EdgeInsets.zero,
                  entry: UpcomingEntry(
                    id: 'allowance',
                    title: 'Allowance',
                    amount: value,
                    dueDate: now,
                    isExpense: false,
                    kind: UpcomingEntryKind.plannedPayment,
                    plannedPayment: allowance,
                  ),
                  currency: currency,
                  onPayPayment: (_) async {
                    opened = true;
                  },
                ),
              ],
            ),
          ),
          size: large ? const Size(320, 640) : const Size(390, 844),
          scale: large ? 1.8 : 1,
        );
        final card = tester.getRect(find.byType(UpcomingEntryTile));
        final title = tester.getRect(find.text('Allowance'));
        final amount = tester.getRect(
          find.text('+${currency.formatter.format(value)}'),
        );
        final subtitle = tester.getRect(find.text('Available anytime'));
        if (large || longAmount) {
          expect(amount.left, closeTo(title.left, .5));
          expect(amount.top, greaterThanOrEqualTo(title.bottom));
          expect(subtitle.top, greaterThanOrEqualTo(amount.bottom));
        } else {
          expect(card.height, lessThan(100));
          expect(amount.right, closeTo(card.right - 16, .5));
          expect(
            amount.center.dy,
            closeTo((title.top + subtitle.bottom) / 2, .5),
          );
          expect(amount.left, greaterThanOrEqualTo(title.right));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(UpcomingEntryTile));
        await tester.pumpAndSettle();
        expect(opened, isTrue);
      },
    );
  }

  testWidgets('transaction account picker keeps privacy and options live', (
    tester,
  ) async {
    final c = await mount(tester, const AddTransactionScreen());
    final accountField = find.byWidgetPredicate(
      (widget) => widget is SelectionTile && widget.label == 'Account',
    );
    await tester.ensureVisible(accountField);
    await tester.tap(accountField);
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel('Hide balance and exclude from totals'),
    );
    await tester.pumpAndSettle();
    expect(c.read(accountProvider).value!.single.excludeFromTotal, isTrue);
    expect(
      tester
          .widget<AccountItem>(find.byType(AccountItem))
          .account
          .excludeFromTotal,
      isTrue,
    );
    await tester.tap(
      find.bySemanticsLabel('Show balance and include in totals'),
    );
    await tester.pumpAndSettle();
    expect(c.read(accountProvider).value!.single.excludeFromTotal, isFalse);
    await c
        .read(accountProvider.notifier)
        .addAccount(account.copyWith(id: 'bank', name: 'New bank'));
    await tester.pumpAndSettle();
    expect(find.text('New bank'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction category picker shows newly created categories', (
    tester,
  ) async {
    final c = await mount(tester, const AddTransactionScreen());
    final categoryField = find.byWidgetPredicate(
      (widget) => widget is SelectionTile && widget.label == 'Category',
    );
    await tester.ensureVisible(categoryField);
    await tester.tap(categoryField);
    await tester.pumpAndSettle();
    await c
        .read(categoriesProvider.notifier)
        .addCategory(category.copyWith(id: 'travel', name: 'Travel'));
    await tester.pumpAndSettle();
    expect(find.text('Travel'), findsOneWidget);
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    expect(tester.widget<SelectionTile>(categoryField).selectedName, 'Travel');
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly trend preserves dates with no spending', (tester) async {
    final expenses = [
      for (final day in [1, 31])
        AppTransaction(
          id: '$day',
          amount: 10,
          date: DateTime(2026, 10, day),
          accountId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
        ),
    ];
    await mount(
      tester,
      Scaffold(
        body: SpendingTrendChart(
          expenses: expenses,
          currency: Currency.defaultCurrency,
          filterIndex: 1,
          baseDate: now,
        ),
      ),
    );
    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    expect(data.barGroups, hasLength(31));
    expect(data.barGroups[15].barRods.single.toY, 0);
    expect(data.barGroups.last.barRods.single.toY, 10);
    await tester.tap(find.text('View amounts'));
    await tester.pumpAndSettle();
    expect(find.text('Spending amounts'), findsOneWidget);
  });

  testWidgets('active filter Clear meets the Android touch target', (
    tester,
  ) async {
    final c = await mount(
      tester,
      const Scaffold(body: TransactionsListScreen()),
    );
    c
        .read(transactionFilterProvider.notifier)
        .updateFilter(const TransactionFilter(type: TransactionType.expense));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    final targets = await androidTapTargetGuideline.evaluate(tester);
    expect(targets.passed, isTrue, reason: targets.reason);
    semantics.dispose();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(c.read(transactionFilterProvider).isEmpty, isTrue);
  });
  for (final radio in [false, true]) {
    testWidgets('search picker stays usable with keyboard: radio=$radio', (
      tester,
    ) async {
      String? selected;
      await mount(
        tester,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async {
                selected = radio
                    ? await showRadioSelectionSheet<String>(
                        context: context,
                        title: 'Currency',
                        options: List.generate(15, (i) => 'Currency $i'),
                        selected: 'Currency 0',
                        label: (s) => s,
                      )
                    : await showAccountPickerSheet(
                        context: context,
                        ref: ref,
                        selectedAccountId: 'cash',
                      );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
        size: const Size(320, 640),
        scale: 1.8,
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byType(TextField),
        radio ? 'Currency 14' : 'Cash',
      );
      await tester.pumpAndSettle();
      final result = find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data == (radio ? 'Currency 14' : 'Cash'),
      );
      await tester.ensureVisible(result);
      await tester.pumpAndSettle();
      expect(result.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(selected, radio ? 'Currency 14' : 'cash');
    });
  }
}
