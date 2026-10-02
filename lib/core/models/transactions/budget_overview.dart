import 'package:koin/core/models/accounts/account.dart';
import 'package:koin/core/models/transactions/category.dart';
import 'package:koin/core/models/transactions/transaction.dart';

/// Metrics computed for an individual category's budget allocation.
class CategoryBudgetMetrics {
  final TransactionCategory category;
  final double budget;
  final double spent;
  final double progress;
  final double remaining;
  final bool isOverBudget;

  const CategoryBudgetMetrics({
    required this.category,
    required this.budget,
    required this.spent,
    required this.progress,
    required this.remaining,
    required this.isOverBudget,
  });

  /// Spending percentage relative to budget.
  double get percent => budget > 0 ? (spent / budget * 100) : 0.0;

  /// String formatted percentage e.g. "85%".
  String get formattedPercent => '${percent.toStringAsFixed(0)}%';

  /// The monetary amount spent exceeding the budget limit, or 0.0 if not exceeded.
  double get overBudgetAmount => isOverBudget ? (spent - budget) : 0.0;

  /// Whether current spending is within 80% to 100% of the allocated budget.
  bool get isNearLimit => progress > 0.8 && !isOverBudget;
}

/// Deep Domain Module: Encapsulates budget evaluation, spending aggregation,
/// category progress calculations, and over-budget tracking.
class BudgetOverview {
  final List<TransactionCategory> budgetedCategories;
  final List<TransactionCategory> unbudgetedCategories;
  final double totalBudget;
  final double totalSpent;
  final double overallProgress;
  final String overallPercent;
  final Map<String, CategoryBudgetMetrics> metricsByCategory;

  const BudgetOverview({
    required this.budgetedCategories,
    required this.unbudgetedCategories,
    required this.totalBudget,
    required this.totalSpent,
    required this.overallProgress,
    required this.overallPercent,
    required this.metricsByCategory,
  });

  factory BudgetOverview.calculate({
    required List<TransactionCategory> categories,
    required Map<String, double> categorySpending,
    required double totalIncome,
  }) {
    final expenseCategories = categories
        .where((c) => c.type == TransactionType.expense)
        .toList();

    final budgeted = expenseCategories.where((c) => c.hasBudget).toList();
    final unbudgeted = expenseCategories.where((c) => !c.hasBudget).toList();

    double sumBudget = 0.0;
    double sumSpent = 0.0;
    final Map<String, CategoryBudgetMetrics> metrics = {};

    for (final cat in budgeted) {
      final resBudget = cat.resolvedBudget(totalIncome);
      final spent = categorySpending[cat.id] ?? 0.0;
      final progress = resBudget > 0 ? (spent / resBudget).clamp(0.0, 1.0) : 0.0;
      final remaining = (resBudget - spent).clamp(0.0, double.infinity);
      final isOver = resBudget > 0 && spent > resBudget;

      sumBudget += resBudget;
      sumSpent += spent;

      metrics[cat.id] = CategoryBudgetMetrics(
        category: cat,
        budget: resBudget,
        spent: spent,
        progress: progress,
        remaining: remaining,
        isOverBudget: isOver,
      );
    }

    final progress = sumBudget > 0
        ? (sumSpent / sumBudget).clamp(0.0, 1.0)
        : 0.0;
    final percent = sumBudget > 0
        ? (sumSpent / sumBudget * 100).toStringAsFixed(0)
        : '0';

    return BudgetOverview(
      budgetedCategories: budgeted,
      unbudgetedCategories: unbudgeted,
      totalBudget: sumBudget,
      totalSpent: sumSpent,
      overallProgress: progress,
      overallPercent: percent,
      metricsByCategory: metrics,
    );
  }

  /// Factory calculating budget metrics for a given [month] directly from [transactions] and optional [accounts].
  factory BudgetOverview.calculateForMonth({
    required List<TransactionCategory> categories,
    required List<AppTransaction> transactions,
    List<Account> accounts = const [],
    DateTime? month,
  }) {
    final targetMonth = month ?? DateTime.now();
    final includedAccountIds = accounts.isEmpty
        ? null
        : accounts
            .where((a) => !a.excludeFromTotal)
            .map((a) => a.id)
            .toSet();

    double totalIncome = 0.0;
    final Map<String, double> categorySpending = {};

    for (final t in transactions) {
      if (t.date.year != targetMonth.year || t.date.month != targetMonth.month) {
        continue;
      }

      final isSourceIncluded = includedAccountIds == null ||
          includedAccountIds.contains(t.accountId);
      final isDestIncluded = t.toAccountId != null &&
          (includedAccountIds == null ||
              includedAccountIds.contains(t.toAccountId));

      if (t.type == TransactionType.income) {
        if (isSourceIncluded) totalIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        if (isSourceIncluded) {
          categorySpending[t.categoryId] =
              (categorySpending[t.categoryId] ?? 0.0) + t.amount;
        }
      } else if (t.type == TransactionType.transfer) {
        if (!isSourceIncluded && isDestIncluded) {
          totalIncome += t.amount;
        }
      }
    }

    return BudgetOverview.calculate(
      categories: categories,
      categorySpending: categorySpending,
      totalIncome: totalIncome,
    );
  }
}

