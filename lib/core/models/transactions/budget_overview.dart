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
}
