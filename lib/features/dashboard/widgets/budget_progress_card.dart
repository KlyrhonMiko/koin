import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

/// A quick preview of the category budgets needing the most attention.
class BudgetProgressCard extends StatelessWidget {
  final BudgetOverview overview;
  final Currency currency;
  final VoidCallback onManage;

  const BudgetProgressCard({
    super.key,
    required this.overview,
    required this.currency,
    required this.onManage,
  });

  String _money(double value) =>
      NumberFormat.compactCurrency(symbol: currency.symbol).format(value);

  @override
  Widget build(BuildContext context) {
    final budgets = overview.budgetedCategories
        .map((category) => overview.metricsByCategory[category.id])
        .whereType<CategoryBudgetMetrics>()
        .toList();
    budgets.sort((a, b) {
      final over = (b.isOverBudget ? 1 : 0).compareTo(a.isOverBudget ? 1 : 0);
      return over != 0 ? over : b.percent.compareTo(a.percent);
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (budgets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No budgets yet',
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontSize: KoinTypography.compact,
                      fontWeight: KoinTypography.titleWeight,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    'Set a monthly limit to track your spending.',
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: KoinTypography.small,
                    ),
                  ),
                  TextButton(
                    onPressed: onManage,
                    child: const Text('Set budgets'),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < budgets.take(3).length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppTheme.dividerColor(context)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _category(context, budgets[i]),
            ),
          ],
          if (budgets.length > 3)
            TextButton(
              onPressed: onManage,
              child: Text('View all ${budgets.length} budgets'),
            ),
        ],
      ),
    );
  }

  Widget _category(BuildContext context, CategoryBudgetMetrics metrics) {
    final category = metrics.category;
    final color = metrics.isOverBudget
        ? AppTheme.errorColor(context)
        : AppTheme.primaryColor(context);
    final status = metrics.budget == 0
        ? 'Awaiting income'
        : metrics.isOverBudget
        ? '${_money(metrics.overBudgetAmount)} over'
        : '${_money(metrics.remaining)} left';
    final amountStyle = TextStyle(
      color: metrics.isOverBudget ? color : AppTheme.textLightColor(context),
      fontSize: KoinTypography.small,
      fontWeight: KoinTypography.labelWeight,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            IconUtils.getIcon(category.iconCodePoint),
            size: 17,
            color: category.color,
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final name = Text(
                    category.name,
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontSize: KoinTypography.compact,
                      fontWeight: KoinTypography.titleWeight,
                    ),
                  );
                  final amount = Text(status, style: amountStyle);
                  if (constraints.maxWidth < 220 ||
                      MediaQuery.textScalerOf(context).scale(14) > 19) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [name, const Gap(4), amount],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: name),
                      const Gap(12),
                      amount,
                    ],
                  );
                },
              ),
              const Gap(8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: metrics.progress.clamp(0.0, 1.0),
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) => LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: AppTheme.surfaceLightColor(context),
                  color: color,
                  semanticsLabel: '${category.name}, $status',
                  semanticsValue:
                      '${(metrics.progress.clamp(0.0, 1.0) * 100).round()}%',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
