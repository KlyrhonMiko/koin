import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/account_form_screen.dart';
import 'package:koin/features/budgets/widgets/budget_editor_sheet.dart';
import 'package:koin/features/cashflow/add_edit_cashflow_screen.dart';
import 'package:koin/features/categories/category_detail_screen.dart';
import 'package:koin/features/debts/add_edit_debt_screen.dart';
import 'package:koin/features/debts/widgets/add_purchase_sheet.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/widgets/savings_log_sheet.dart';
import 'package:koin/features/savings/widgets/savings_plan_editor.dart';
import 'package:koin/features/reports/custom_reports_screen.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
import 'package:koin/features/settings/archive_manager_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingLedger extends InMemoryLedgerAdapter {
  final completion = Completer<List<AppTransaction>>();
  @override
  Future<List<AppTransaction>> getTransactions() => completion.future;
}

class _FailingLedger extends InMemoryLedgerAdapter {
  @override
  Future<List<AppTransaction>> getTransactions() async =>
      throw StateError('read failed');
}

class _ProblemPayments extends AutomaticPaymentsNotifier {
  @override
  AutomaticPaymentsState build() => const AutomaticPaymentsState(
    problems: ['Rent: Insufficient balance in Cash'],
  );
}

class _ControlledCategories extends InMemoryCategoryAdapter {
  _ControlledCategories({required super.initial});
  Completer<void>? pending;

  @override
  Future<void> updateCategory(TransactionCategory category) async {
    await pending?.future;
    await super.updateCategory(category);
  }
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final font = FontLoader('Outfit');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      font.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final cash = Account(
    id: 'cash',
    name: 'Cash',
    initialBalance: 1000,
    iconCodePoint: KoinIcons.wallet.codePoint,
    colorHex: '#00D09E',
  );
  final food = TransactionCategory(
    id: 'food',
    name: 'Food',
    iconCodePoint: KoinIcons.forkKnife.codePoint,
    colorHex: '#00D09E',
    type: TransactionType.expense,
  );

  Future<ProviderContainer> providers({
    Ledger? ledger,
    List<Account>? accounts,
    List<TransactionCategory>? categories,
    CategoryRepository? categoryRepository,
    bool paymentProblem = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ledgerProvider.overrideWithValue(ledger ?? InMemoryLedgerAdapter()),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(initial: accounts ?? [cash]),
        ),
        categoryRepositoryProvider.overrideWithValue(
          categoryRepository ??
              InMemoryCategoryAdapter(initial: categories ?? [food]),
        ),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
        plannedPaymentRepositoryProvider.overrideWithValue(
          InMemoryPlannedPaymentAdapter(),
        ),
        debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
        if (paymentProblem)
          automaticPaymentsProvider.overrideWith(_ProblemPayments.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> open(
    WidgetTester tester,
    ProviderContainer container,
    Widget page, {
    Size size = const Size(430, 950),
    bool dark = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), dark),
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('audit-preview'),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
          ),
          home: page,
        ),
      ),
    );
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('audit-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final directory = await Directory('build/audit-previews')
          .create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  testWidgets(
    'archive and report states adapt to narrow screens and large text',
    (tester) async {
      for (final (variant, dark, textScale, size) in [
        ('light', false, 1.0, const Size(430, 950)),
        ('dark', true, 1.0, const Size(430, 950)),
        ('dark-large', true, 1.8, const Size(320, 700)),
      ]) {
        final container = await providers(
          accounts: [
            cash,
            for (final id in ['maribank', 'gcash', 'gotyme', 'maya'])
              Account(
                id: id,
                name: BankTemplate.templates.firstWhere((b) => b.id == id).name,
                iconCodePoint: BankTemplate.templates
                    .firstWhere((b) => b.id == id)
                    .iconCodePoint,
                colorHex: BankTemplate.templates
                    .firstWhere((b) => b.id == id)
                    .colorHex,
                logoAsset: BankTemplate.templates
                    .firstWhere((b) => b.id == id)
                    .logoAsset,
                initialBalance: 1500,
              ),
          ],
          categories: [
            food.withFixedBudget(300),
            food.copyWith(
              id: 'salary',
              name: 'Salary',
              type: TransactionType.income,
              iconCodePoint: KoinIcons.currencyDollar.codePoint,
              colorHex: '#8BC34A',
            ),
          ],
        );
        await open(
          tester,
          container,
          const ArchiveManagerScreen(),
          size: size,
          dark: dark,
          textScale: textScale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AccountItem), findsWidgets);
        if (const bool.fromEnvironment('UI_PREVIEWS')) {
          final context = tester.element(find.byType(ArchiveManagerScreen));
          await tester.runAsync(
            () => Future.wait([
              for (final account in container.read(accountProvider).value!)
                if (account.logoAsset != null)
                  precacheImage(AssetImage(account.logoAsset!), context),
            ]),
          );
          await tester.pump();
        }
        expect(
          tester
              .widgetList<AccountItem>(find.byType(AccountItem))
              .every((card) => card.compact),
          isTrue,
        );
        await preview(tester, 'archive-$variant');
        expect(
          find.text('Tap a card to archive it. History and balances are kept.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Categories'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryItem), findsWidgets);
        expect(tester.takeException(), isNull);
        await preview(tester, 'archive-categories-$variant');
        final reportContainer = await providers(ledger: _FailingLedger());
        await open(
          tester,
          reportContainer,
          const CustomReportsScreen(),
          size: size,
          dark: dark,
          textScale: textScale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.text('Retry')).bottom,
          lessThan(tester.getRect(find.text('Export CSV')).top),
        );
        await preview(tester, 'reports-$variant');
      }
    },
  );

  testWidgets('automatic payment problems offer review and retry recovery', (
    tester,
  ) async {
    final container = await providers(paymentProblem: true);
    await open(tester, container, const Scaffold(body: DashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Automatic payments need attention'), findsOneWidget);
    expect(find.text('Rent: Insufficient balance in Cash'), findsOneWidget);
    await preview(tester, 'automatic-payment-notice');
    await tester.tap(find.text('Review incomes'));
    expect(container.read(portfolioTabProvider), 4);
    expect(container.read(navigationProvider), 3);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Automatic payments need attention'), findsNothing);
  });

  testWidgets('clearing filters also clears the visible search query', (
    tester,
  ) async {
    final container = await providers();
    await open(
      tester,
      container,
      const Scaffold(body: TransactionsListScreen()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all filters'));
    await tester.pumpAndSettle();
    expect(container.read(transactionFilterProvider).query, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
  });

  testWidgets(
    'report export is disabled while loading and enables when ready',
    (tester) async {
      final pending = _PendingLedger();
      final container = await providers(ledger: pending);
      await open(tester, container, const CustomReportsScreen());
      await tester.pump();
      final csv = find.ancestor(
        of: find.text('Export CSV'),
        matching: find.byType(PressableScale),
      );
      expect(find.text('Loading report data…'), findsOneWidget);
      expect(tester.widget<PressableScale>(csv).onTap, isNull);
      pending.completion.complete([]);
      await tester.pumpAndSettle();
      expect(tester.widget<PressableScale>(csv).onTap, isNotNull);
    },
  );

  testWidgets('report read failures show retry and keep export disabled', (
    tester,
  ) async {
    final container = await providers(ledger: _FailingLedger());
    await open(tester, container, const CustomReportsScreen());
    await tester.pumpAndSettle();
    expect(find.text('Could not load report data.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    final csv = find.ancestor(
      of: find.text('Export CSV'),
      matching: find.byType(PressableScale),
    );
    expect(tester.widget<PressableScale>(csv).onTap, isNull);
  });

  testWidgets(
    'archived accounts can be restored without losing their balance',
    (tester) async {
      final container = await providers();
      await open(tester, container, const ArchiveManagerScreen(), dark: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('archive_account_cash')));
      await tester.pumpAndSettle();
      expect(find.text('Archive Cash?'), findsOneWidget);
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();
      expect(container.read(accountProvider).value!.single.isArchived, isTrue);
      final notification = tester.getRect(find.byType(Dismissible));
      expect(notification.height, lessThanOrEqualTo(56));
      expect(
        notification.top,
        greaterThan(tester.getRect(find.byType(TabBar)).bottom),
      );
      await preview(tester, 'archive-notification-dark');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        find.text('Tap a card to restore it to your entry choices.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('archive_account_cash')));
      await tester.pumpAndSettle();
      final restored = container.read(accountProvider).value!.single;
      expect(restored.isArchived, isFalse);
      expect(restored.initialBalance, 1000);
      await preview(tester, 'restore-notification-dark');
    },
  );

  testWidgets(
    'category card archives directly and preserves budget through cancellation and restore',
    (tester) async {
      final container = await providers(
        categories: [food.withFixedBudget(300)],
      );
      await open(tester, container, const ArchiveManagerScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('archive_category_food')));
      await tester.pumpAndSettle();
      expect(find.text('Archive Food?'), findsOneWidget);
      expect(find.byType(PopupMenuItem<bool>), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        container.read(categoriesProvider).value!.single.isArchived,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('archive_category_food')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(
        container.read(categoriesProvider).value!.single.isArchived,
        isTrue,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('archive_category_food')));
      await tester.pumpAndSettle();
      final restored = container.read(categoriesProvider).value!.single;
      expect(restored.isArchived, isFalse);
      expect(restored.budget, 300);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new account choices omit archives but editing keeps the selected archive',
    (tester) async {
      final container = await providers(
        accounts: [
          cash,
          cash.copyWith(id: 'old', name: 'Old bank', isArchived: true),
        ],
      );
      await container.read(accountProvider.future);
      await open(
        tester,
        container,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Column(
              children: [
                TextButton(
                  onPressed: () => showAccountPickerSheet(
                    context: context,
                    ref: ref,
                    selectedAccountId: null,
                  ),
                  child: const Text('Choose'),
                ),
                TextButton(
                  onPressed: () => showAccountPickerSheet(
                    context: context,
                    ref: ref,
                    selectedAccountId: 'old',
                  ),
                  child: const Text('Edit old'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Old bank'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit old'));
      await tester.pumpAndSettle();
      expect(find.text('Old bank'), findsOneWidget);
    },
  );

  testWidgets('palette controls expose accessible names and selected states', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = await providers();
    await open(
      tester,
      container,
      Scaffold(
        body: Column(
          children: [
            ColorPaletteGrid(
              hexColors: const ['#00D09E'],
              selectedHex: '#00D09E',
              onHexSelected: (_) {},
            ),
            IconPaletteGrid(
              activeColor: const Color(0xFF00D09E),
              icons: const [KoinIcons.wallet],
              selectedIcon: KoinIcons.wallet,
              onIconSelected: (_) {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Color #00D09E'), findsOneWidget);
    expect(find.bySemanticsLabel('Wallet'), findsOneWidget);
    expect(
      tester
          .widgetList<PressableScale>(find.byType(PressableScale))
          .every((button) => button.selected == true),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('busy transaction days mount only visible rows', (tester) async {
    final now = DateTime.now();
    final container = await providers(
      ledger: InMemoryLedgerAdapter(
        initial: [
          for (var i = 0; i < 1000; i++)
            AppTransaction(
              id: 'tx_$i',
              note: 'Purchase $i',
              amount: 1,
              date: now,
              type: TransactionType.expense,
              categoryId: food.id,
              accountId: cash.id,
            ),
        ],
      ),
    );
    await open(
      tester,
      container,
      const Scaffold(body: TransactionsListScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TransactionTile).evaluate().length, lessThan(40));
    expect(find.byType(TransactionTile), findsWidgets);
  });

  final date = DateTime(2026, 10, 21);
  final goal = SavingsGoal(
    id: 'goal',
    name: 'Holiday',
    targetAmount: 5000,
    startDate: date,
    endDate: date.add(const Duration(days: 60)),
  );
  final payment = PlannedPayment(
    id: 'payment',
    title: 'Rent',
    amount: 100,
    type: TransactionType.expense,
    categoryId: food.id,
    accountId: cash.id,
    startDate: date,
    nextDate: date,
    frequency: PaymentFrequency.monthly,
  );
  final debt = Debt(
    id: 'debt',
    personName: 'Alex',
    amount: 100,
    type: DebtType.owedToMe,
    startDate: date,
  );
  final editors = <(String, Widget, String, String)>[
    ('account', AccountFormScreen(account: cash), 'Cash', 'account'),
    ('category', CategoryDetailScreen(category: food), 'Food', 'category'),
    ('debt', AddEditDebtScreen(debt: debt), 'Alex', 'debt'),
    (
      'scheduled payment',
      AddEditCashflowScreen(payment: payment),
      'Rent',
      'schedule',
    ),
    ('savings goal', AddSavingsGoalScreen(goal: goal), 'Holiday', 'savings'),
    (
      'savings plan',
      SavingsPlanEditor(
        initial: SavingsPlan(
          amount: 200,
          frequency: SavingsFrequency.weekly,
          startDate: date,
        ),
      ),
      '200.00',
      'plan',
    ),
  ];

  for (final (name, editor, original, prompt) in editors) {
    testWidgets(
      '$name protects edits, preserves Cancel, and allows reverted drafts',
      (tester) async {
        final container = await providers();
        await container.read(accountProvider.future);
        await container.read(categoriesProvider.future);
        await open(
          tester,
          container,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<Object?>(builder: (_) => editor),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        );
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        Future<void> launch() async {
          await tester.tap(find.text('Open editor'));
          await tester.pumpAndSettle();
        }

        Finder field(String text) => find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == text,
        );

        await launch();
        await navigator.maybePop();
        await tester.pumpAndSettle();
        expect(find.text('Open editor'), findsOneWidget);
        expect(find.text('Discard $prompt changes?'), findsNothing);

        await launch();
        await tester.enterText(
          field(original),
          name == 'savings plan' ? '250' : 'Changed draft',
        );
        await tester.pump();
        await navigator.maybePop();
        await tester.pumpAndSettle();
        expect(find.text('Discard $prompt changes?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        final changed = name == 'savings plan' ? '250' : 'Changed draft';
        expect(field(changed), findsOneWidget);

        await tester.enterText(field(changed), original);
        await tester.pump();
        await navigator.maybePop();
        await tester.pumpAndSettle();
        expect(find.text('Open editor'), findsOneWidget);

        await launch();
        await tester.enterText(field(original), changed);
        await tester.pump();
        await navigator.maybePop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.text('Open editor'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final sheet in ['budget', 'savings', 'purchase']) {
    testWidgets('$sheet sheet protects drag, close, and barrier dismissal', (
      tester,
    ) async {
      final container = await providers();
      await container.read(categoriesProvider.future);
      final item = DebtItem(
        id: 'purchase',
        debtId: debt.id,
        name: 'Laptop',
        amount: 100,
        totalInstallments: 2,
        firstPaymentDate: date,
        categoryId: food.id,
      );
      var saved = false;
      DebtItem? savedPurchase;
      await open(
        tester,
        container,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                if (sheet == 'budget') {
                  BudgetEditorSheet.show(
                    context,
                    category: food.withFixedBudget(100),
                    currency: container.read(settingsProvider).currency,
                    totalIncome: 1000,
                  );
                } else if (sheet == 'savings') {
                  SavingsLogSheet.show(
                    context: context,
                    goal: goal,
                    log: SavingsLog(
                      id: 'log',
                      goalId: goal.id,
                      amount: 100,
                      date: date,
                    ),
                    onSave: (_) async => saved = true,
                  );
                } else {
                  showAddPurchaseSheet(
                    context: context,
                    debtType: DebtType.iOwe,
                    primaryColor: AppTheme.primaryColor(context),
                    categories: [food],
                    defaultDate: date,
                    existingItem: item,
                  ).then((value) => savedPurchase = value);
                }
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      );
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      Future<void> launch() async {
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
      }

      await launch();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesGuard), findsNothing);

      await launch();
      if (sheet == 'purchase') {
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.controller?.text == 'Laptop',
          ),
          'Changed laptop',
        );
      } else {
        await tester.tap(find.text('1'));
      }
      await tester.pump();
      final handlePosition = tester.getCenter(
        find.byType(KoinBottomSheetHandle),
      );
      await tester.flingFrom(handlePosition, const Offset(0, 500), 1200);
      await tester.pumpAndSettle();
      expect(find.text('Discard $sheet changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesGuard), findsOneWidget);
      expect(
        tester.getCenter(find.byType(KoinBottomSheetHandle)).dy,
        closeTo(handlePosition.dy, 1),
      );
      if (sheet == 'purchase') {
        expect(find.text('Changed laptop'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
      } else {
        expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '1');
        navigator.pop();
      }
      await tester.pumpAndSettle();
      expect(find.text('Discard $sheet changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Discard $sheet changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesGuard), findsNothing);
      expect(saved, isFalse);
      expect(savedPurchase, isNull);

      await launch();
      if (sheet == 'purchase') {
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.controller?.text == 'Laptop',
          ),
          'Saved laptop',
        );
        await tester.tap(find.text('Update Plan'));
      } else {
        await tester.tap(find.text('1'));
        await tester.tap(find.text('Save'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesGuard), findsNothing);
      expect(find.text('Discard $sheet changes?'), findsNothing);
      if (sheet == 'purchase') {
        expect(savedPurchase?.name, 'Saved laptop');
        expect(savedPurchase?.id, item.id);
      } else if (sheet == 'savings') {
        expect(saved, isTrue);
      } else {
        expect(
          (await container.read(categoriesProvider.future)).single.budget,
          1,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'category save blocks exit while pending, preserves failure, and closes on retry',
    (tester) async {
      final repository = _ControlledCategories(initial: [food]);
      final container = await providers(categoryRepository: repository);
      await container.read(categoriesProvider.future);
      await open(
        tester,
        container,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CategoryDetailScreen(category: food),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == 'Food',
        ),
        'Updated food',
      );
      repository.pending = Completer<void>();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await navigator.maybePop();
      await tester.pump();
      expect(find.byType(CategoryDetailScreen), findsOneWidget);
      expect(find.text('Discard category changes?'), findsNothing);
      repository.pending!.completeError(StateError('write failed'));
      await tester.pumpAndSettle();
      expect(find.text('Could not save category'), findsOneWidget);
      await preview(tester, 'notification-error-light');
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Discard category changes?'), findsOneWidget);
      expect(find.text('Could not save category'), findsNothing);
      await preview(tester, 'discard-category-light');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Updated food'), findsWidgets);
      repository.pending = null;
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect((await repository.getCategories()).single.name, 'Updated food');
    },
  );

  testWidgets(
    'picker-only plan changes confirm discard in dark mode and large text',
    (tester) async {
      final container = await providers();
      await open(
        tester,
        container,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SavingsPlanEditor.open(
                context,
                initial: SavingsPlan(
                  amount: 200,
                  frequency: SavingsFrequency.weekly,
                  startDate: date,
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
        dark: true,
        textScale: 1.6,
        size: const Size(320, 700),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard plan changes?'), findsOneWidget);
      await preview(tester, 'discard-plan-dark-large');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Monthly'), findsWidgets);
      await tester.ensureVisible(find.text('Save plan'));
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving an edited transaction preserves changes until discard is confirmed',
    (tester) async {
      final tx = AppTransaction(
        id: 'existing',
        note: 'Original note',
        amount: 10,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: food.id,
        accountId: cash.id,
      );
      final container = await providers(
        ledger: InMemoryLedgerAdapter(initial: [tx]),
      );
      await container.read(transactionProvider.future);
      await open(
        tester,
        container,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AddTransactionScreen(editingTransaction: tx),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final note = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'Original note',
      );
      await tester.enterText(note, 'Changed note');
      await tester.pump();
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Discard transaction changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Changed note'), findsOneWidget);
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect(
        (await container.read(ledgerProvider).getTransactions()).single.note,
        'Original note',
      );
    },
  );
}
