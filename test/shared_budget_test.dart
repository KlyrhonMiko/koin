import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/database_version.dart';
import 'package:koin/core/maintenance/database_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ReadFailureAfterBudgetSave extends InMemoryCategoryAdapter {
  _ReadFailureAfterBudgetSave({required super.initial});
  bool saved = false;
  @override
  Future<List<TransactionCategory>> getCategories() async {
    if (saved) throw StateError('reload failed');
    return super.getCategories();
  }

  @override
  Future<void> updateBudgets(List<TransactionCategory> categories) async {
    await super.updateBudgets(categories);
    saved = true;
  }
}

TransactionCategory category(String id) => TransactionCategory(
  id: id,
  name: id,
  iconCodePoint: KoinIcons.forkKnife.codePoint,
  colorHex: '#009688',
  type: TransactionType.expense,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final food = category('Food')
      .withPercentBudget(25)
      .copyWith(sharedBudgetCategoryIds: ['Drinks']);
  final drinks = category('Drinks');

  for (final split in [(4000.0, 1000.0), (1000.0, 4000.0)]) {
    test('one 25% allocation allows the spending split $split', () {
      final overview = BudgetOverview.calculate(
        categories: [
          food,
          drinks,
          category('Shopping'),
          category('Travel').withPercentBudget(10),
        ],
        categorySpending: {'Food': split.$1, 'Drinks': split.$2, 'Travel': 750},
        totalIncome: 20000,
      );
      final metrics = overview.metricsByCategory['Food']!;
      expect(metrics.name, 'Food + Drinks');
      expect(metrics.budget, 5000);
      expect(metrics.spent, 5000);
      expect(metrics.remaining, 0);
      expect(metrics.isOverBudget, isFalse);
      expect(overview.totalBudget, 7000);
      expect(overview.totalSpent, 5750);
      expect(overview.budgetedCategories.map((c) => c.id), ['Food', 'Travel']);
      expect(overview.unbudgetedCategories.single.id, 'Shopping');
    });
  }

  test(
    'shared overspending, fixed amounts and no income use combined spending',
    () {
      BudgetOverview overview(TransactionCategory budget, double income) =>
          BudgetOverview.calculate(
            categories: [budget, drinks],
            categorySpending: {'Food': 1000, 'Drinks': 4500},
            totalIncome: income,
          );
      final percent = overview(food, 20000).metricsByCategory['Food']!;
      expect(percent.isOverBudget, isTrue);
      expect(percent.overBudgetAmount, 500);
      expect(percent.progress, 1);
      expect(overview(food, 0).metricsByCategory['Food']!.spent, 5500);
      final fixed = overview(food.withFixedBudget(6000), 0);
      expect(fixed.totalBudget, 6000);
      expect(fixed.metricsByCategory['Food']!.remaining, 500);
    },
  );

  test('removing or detaching a shared budget releases its categories', () {
    final cleared = food.withoutBudget();
    expect(cleared.sharedBudgetCategoryIds, isEmpty);
    final removed = BudgetOverview.calculate(
      categories: [cleared, drinks],
      categorySpending: {},
      totalIncome: 20000,
    );
    expect(removed.unbudgetedCategories, hasLength(2));
    final detached = BudgetOverview.calculate(
      categories: [
        food.copyWith(sharedBudgetCategoryIds: []),
        drinks,
      ],
      categorySpending: {'Food': 4000, 'Drinks': 1000},
      totalIncome: 20000,
    );
    expect(detached.totalSpent, 4000);
    expect(detached.unbudgetedCategories.single.id, 'Drinks');
  });

  test('serialization and budget/category edits preserve sharing', () {
    final restored = TransactionCategory.fromMap(food.toMap());
    expect(restored.sharedBudgetCategoryIds, ['Drinks']);
    expect(restored.withFixedBudget(5000).sharedBudgetCategoryIds, ['Drinks']);
    expect(restored.withPercentBudget(30).sharedBudgetCategoryIds, ['Drinks']);
    expect(restored.copyWith(name: 'Meals').sharedBudgetCategoryIds, [
      'Drinks',
    ]);
    final legacy = food.toMap()..remove('sharedBudgetCategoryIds');
    expect(
      TransactionCategory.fromMap(legacy).sharedBudgetCategoryIds,
      isEmpty,
    );
  });

  test(
    'monthly shared budgets include both accounts and exclude other months',
    () {
      final month = DateTime(2026, 11);
      AppTransaction transaction(
        String id,
        String cat,
        double amount, {
        String account = 'cash',
        TransactionType type = TransactionType.expense,
        DateTime? date,
      }) => AppTransaction(
        id: id,
        amount: amount,
        date: date ?? month,
        type: type,
        categoryId: cat,
        accountId: account,
      );
      final overview = BudgetOverview.calculateForMonth(
        categories: [food, drinks],
        month: month,
        transactions: [
          transaction('salary', 'salary', 20000, type: TransactionType.income),
          transaction('meal', 'Food', 4000),
          transaction('coffee', 'Drinks', 1000, account: 'bank'),
          transaction('previous', 'Drinks', 999, date: DateTime(2026, 10, 31)),
          transaction(
            'transfer',
            'Drinks',
            999,
            type: TransactionType.transfer,
          ),
        ],
      );
      expect(overview.totalBudget, 5000);
      expect(overview.totalSpent, 5000);
    },
  );

  test(
    'a category cannot have its own budget and join another shared budget',
    () async {
      final repository = InMemoryCategoryAdapter(
        initial: [food, drinks, category('Travel')],
      );
      final container = ProviderContainer(
        overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(categoriesProvider.future);
      final notifier = container.read(categoriesProvider.notifier);
      await expectLater(
        notifier.editCategory(drinks.withPercentBudget(10)),
        throwsStateError,
      );
      await expectLater(
        notifier.editCategory(
          category('Travel')
              .withFixedBudget(1000)
              .copyWith(sharedBudgetCategoryIds: ['Drinks']),
        ),
        throwsStateError,
      );
      await expectLater(
        notifier.editCategory(
          food.copyWith(sharedBudgetCategoryIds: ['missing']),
        ),
        throwsStateError,
      );
      expect(
        (await repository.getCategories()).where((c) => c.hasBudget),
        hasLength(1),
      );
      await notifier.editCategory(food.copyWith(sharedBudgetCategoryIds: []));
      await notifier.editCategory(drinks.withPercentBudget(10));
      expect(
        (await repository.getCategories()).where((c) => c.hasBudget),
        hasLength(2),
      );
    },
  );

  group('SQLite persistence and upgrade', () {
    final helper = DatabaseHelper.instance;
    late Directory directory;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      directory = await Directory.systemTemp.createTemp('koin_shared_budget_');
      await databaseFactory.setDatabasesPath(directory.path);
    });
    tearDown(() async {
      await helper.close();
      await directory.delete(recursive: true);
    });

    test(
      'deleting either category preserves the remaining shared budget',
      () async {
        await helper.insertCategory(
          food.copyWith(sharedBudgetCategoryIds: ['Drinks', 'Coffee']),
        );
        await helper.insertCategory(drinks);
        await helper.insertCategory(category('Coffee'));
        await helper.deleteCategory('Drinks');
        var categories = await helper.getCategories();
        expect(
          categories.firstWhere((c) => c.id == 'Food').sharedBudgetCategoryIds,
          ['Coffee'],
        );
        await helper.deleteCategory('Food');
        categories = await helper.getCategories();
        final remaining = categories.firstWhere((c) => c.id == 'Coffee');
        expect(remaining.budgetPercent, 25);
        expect(remaining.sharedBudgetCategoryIds, isEmpty);
        expect(
          BudgetOverview.calculate(
            categories: categories,
            categorySpending: {'Coffee': 1000},
            totalIncome: 20000,
          ).totalBudget,
          5000,
        );
      },
    );

    test('changing category type transfers a fixed shared limit without rejoining later', () async {
      await helper.insertCategory(food.withFixedBudget(5000));
      await helper.insertCategory(drinks);
      await helper.updateCategory(
        food.copyWith(type: TransactionType.income).withoutBudget(),
      );
      var categories = await helper.getCategories();
      final income = categories.firstWhere((c) => c.id == 'Food');
      expect(income.hasBudget, isFalse);
      expect(categories.firstWhere((c) => c.id == 'Drinks').budget, 5000);
      await helper.updateCategory(
        income.copyWith(type: TransactionType.expense),
      );
      categories = await helper.getCategories();
      expect(categories.firstWhere((c) => c.id == 'Food').hasBudget, isFalse);
      expect(
        categories.firstWhere((c) => c.id == 'Drinks').sharedBudgetCategoryIds,
        isEmpty,
      );
    });

    test('failed budget transfer rolls back category deletion', () async {
      await helper.insertCategory(food);
      await helper.insertCategory(drinks);
      final db = await helper.database;
      await db.execute(
        "CREATE TRIGGER reject_budget BEFORE UPDATE ON categories "
        "WHEN NEW.id = 'Drinks' BEGIN SELECT RAISE(ABORT, 'disk write failed'); END",
      );
      await expectLater(
        helper.deleteCategory('Food'),
        throwsA(isA<DatabaseException>()),
      );
      final categories = await helper.getCategories();
      expect(categories.firstWhere((c) => c.id == 'Food').budgetPercent, 25);
      expect(categories.firstWhere((c) => c.id == 'Drinks').hasBudget, isFalse);
    });

    test(
      'moving a budget to another category is atomic if a write fails',
      () async {
        await helper.insertCategory(food);
        await helper.insertCategory(drinks);
        final db = await helper.database;
        await db.execute(
          "CREATE TRIGGER reject_budget BEFORE UPDATE ON categories "
          "WHEN NEW.id = 'Drinks' BEGIN SELECT RAISE(ABORT, 'disk write failed'); END",
        );
        await expectLater(
          helper.updateCategoryBudgets([
            food.withoutBudget(),
            drinks.withPercentBudget(25),
          ]),
          throwsA(isA<DatabaseException>()),
        );
        final restored = await helper.getCategories();
        expect(restored.firstWhere((c) => c.id == 'Food').budgetPercent, 25);
        expect(
          restored.firstWhere((c) => c.id == 'Food').sharedBudgetCategoryIds,
          ['Drinks'],
        );
        expect(restored.firstWhere((c) => c.id == 'Drinks').hasBudget, isFalse);
      },
    );

    test('upgrades version 51 without changing existing budgets, then persists sharing and backups', () async {
      var db = await helper.database;
      await helper.insertCategory(food.copyWith(sharedBudgetCategoryIds: []));
      await helper.insertCategory(drinks);
      await db.execute(
        'ALTER TABLE categories DROP COLUMN sharedBudgetCategoryIds',
      );
      await db.setVersion(51);
      await helper.close();

      db = await helper.database;
      expect(await db.getVersion(), databaseSchemaVersion);
      var saved = (await helper.getCategories()).firstWhere(
        (c) => c.id == 'Food',
      );
      expect(saved.budgetPercent, 25);
      expect(saved.sharedBudgetCategoryIds, isEmpty);
      await helper.updateCategory(food);
      await helper.close();
      db = await helper.database;
      saved = (await helper.getCategories()).firstWhere((c) => c.id == 'Food');
      expect(saved.sharedBudgetCategoryIds, ['Drinks']);

      final backupPath = '${directory.path}/backup.db';
      await DatabaseSnapshot.create(db, backupPath);
      final backup = await openDatabase(
        backupPath,
        readOnly: true,
        singleInstance: false,
      );
      try {
        final row = (await backup.query(
          'categories',
          where: 'id = ?',
          whereArgs: ['Food'],
        )).single;
        expect(TransactionCategory.fromMap(row).sharedBudgetCategoryIds, [
          'Drinks',
        ]);
      } finally {
        await backup.close();
      }
    });
  });

  test(
    'editing coverage can remove the original category and retain the limit',
    () async {
      final repo = InMemoryCategoryAdapter(initial: [food, drinks]);
      final container = ProviderContainer(
        overrides: [categoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(categoriesProvider.future);
      await container
          .read(categoriesProvider.notifier)
          .saveBudget(
            categoryIds: {'Drinks'},
            originalBudgetId: 'Food',
            amount: 25,
            isPercent: true,
          );
      final categories = await repo.getCategories();
      expect(categories.firstWhere((c) => c.id == 'Food').hasBudget, isFalse);
      expect(categories.firstWhere((c) => c.id == 'Drinks').budgetPercent, 25);
      expect(
        BudgetOverview.calculate(
          categories: categories,
          categorySpending: {'Drinks': 1000},
          totalIncome: 20000,
        ).totalBudget,
        5000,
      );
    },
  );

  test('successful saves do not depend on a later reload', () async {
    final repo = _ReadFailureAfterBudgetSave(initial: [food, drinks]);
    final container = ProviderContainer(
      overrides: [categoryRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(categoriesProvider.future);
    await container
        .read(categoriesProvider.notifier)
        .saveBudget(
          categoryIds: {'Food', 'Drinks'},
          originalBudgetId: 'Food',
          amount: 30,
          isPercent: true,
        );
    expect(repo.saved, isTrue);
    final state = container.read(categoriesProvider).requireValue;
    expect(state.firstWhere((c) => c.id == 'Food').budgetPercent, 30);
  });

  test(
    'category type edits keep shared limits and membership reactive',
    () async {
      final repo = InMemoryCategoryAdapter(
        initial: [food, drinks, category('Coffee')],
      );
      final container = ProviderContainer(
        overrides: [categoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(categoriesProvider.future);
      final notifier = container.read(categoriesProvider.notifier);
      await notifier.editCategory(
        food.copyWith(type: TransactionType.income).withoutBudget(),
      );
      final categories = container.read(categoriesProvider).requireValue;
      final remaining = categories.firstWhere((c) => c.id == 'Drinks');
      expect(remaining.budgetPercent, 25);
      expect(remaining.sharedBudgetCategoryIds, isEmpty);
      expect(
        (await repo.getCategories())
            .firstWhere((c) => c.id == 'Drinks')
            .budgetPercent,
        25,
      );
      await notifier.editCategory(
        remaining.copyWith(sharedBudgetCategoryIds: ['Coffee']),
      );
      await notifier.editCategory(
        category('Coffee').copyWith(type: TransactionType.income),
      );
      expect(
        container
            .read(categoriesProvider)
            .requireValue
            .firstWhere((c) => c.id == 'Drinks')
            .sharedBudgetCategoryIds,
        isEmpty,
      );
    },
  );

  test('combining separate budgets replaces allocations once and keeps category identities', () async {
    final repo = InMemoryCategoryAdapter(
      initial: [
        food.copyWith(sharedBudgetCategoryIds: []),
        drinks.withPercentBudget(10),
      ],
    );
    final container = ProviderContainer(
      overrides: [categoryRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(categoriesProvider.future);
    await container
        .read(categoriesProvider.notifier)
        .saveBudget(
          categoryIds: {'Food', 'Drinks'},
          amount: 25,
          isPercent: true,
        );
    final categories = await repo.getCategories();
    final overview = BudgetOverview.calculate(
      categories: categories,
      categorySpending: {'Food': 4000, 'Drinks': 1000},
      totalIncome: 20000,
    );
    expect(overview.budgetedCategories, hasLength(1));
    expect(overview.totalBudget, 5000);
    expect(overview.totalSpent, 5000);
    expect(categories.map((c) => c.name), ['Food', 'Drinks']);
  });

  test(
    'moving an owning category leaves its old group with the same limit',
    () async {
      final coffee = category('Coffee');
      final repo = InMemoryCategoryAdapter(initial: [food, drinks, coffee]);
      final container = ProviderContainer(
        overrides: [categoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(categoriesProvider.future);
      await container
          .read(categoriesProvider.notifier)
          .saveBudget(
            categoryIds: {'Food', 'Coffee'},
            amount: 10,
            isPercent: true,
          );
      final categories = await repo.getCategories();
      expect(categories.firstWhere((c) => c.id == 'Drinks').budgetPercent, 25);
      expect(
        categories.firstWhere((c) => c.id == 'Drinks').sharedBudgetCategoryIds,
        isEmpty,
      );
      expect(
        categories.firstWhere((c) => c.id == 'Food').sharedBudgetCategoryIds,
        ['Coffee'],
      );
      await expectLater(
        container
            .read(categoriesProvider.notifier)
            .saveBudget(
              categoryIds: {'Food', 'Coffee'},
              originalBudgetId: 'Food',
              amount: 80,
              isPercent: true,
            ),
        throwsStateError,
      );
      expect(
        (await repo.getCategories())
            .firstWhere((c) => c.id == 'Food')
            .budgetPercent,
        10,
      );
    },
  );
}
