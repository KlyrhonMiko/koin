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

    if (budgets.isEmpty) {
      return KoinEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No budgets yet',
        subtitle: 'Set a monthly limit to track your spending',
        action: TextButton(
          onPressed: onManage,
          child: const Text('Set budgets'),
        ),
      );
    }

    final previewBudgets = budgets.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final metrics in previewBudgets)
          _buildBudgetCard(context, metrics),
        if (budgets.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TextButton(
              onPressed: onManage,
              child: Text('View all ${budgets.length} budgets'),
            ),
          ),
      ],
    );
  }

  Widget _buildBudgetCard(BuildContext context, CategoryBudgetMetrics metrics) {
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

    return PressableScale(
      onTap: () {
        HapticService.light();
        onManage();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            AppTheme.boxShadow(
              context,
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                IconUtils.getIcon(category.iconCodePoint),
                size: 20,
                color: category.color,
              ),
            ),
            const Gap(14),
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
                          fontSize: KoinTypography.body,
                          fontWeight: KoinTypography.titleWeight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        crossAxisAlignment: CrossAxisAlignment.center,
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
        ),
      ),
    );
  }
}
