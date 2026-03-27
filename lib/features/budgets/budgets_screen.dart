import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/numpad.dart';
import 'package:koin/features/categories/category_manager_screen.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/features/categories/category_detail_screen.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final currency = settings.currency;

    return categoriesAsync.when(
      data: (categories) {
        final totalIncome = stats.totalIncome;

        // Resolve percentage-based budgets to actual amounts
        double resolvedBudget(TransactionCategory c) {
          if (c.isPercentBudget && c.budgetPercent != null && c.budgetPercent! > 0) {
            return totalIncome * c.budgetPercent! / 100;
          }
          return c.budget ?? 0;
        }

        final budgeted = categories.where((c) => c.type == TransactionType.expense && ((c.budget != null && c.budget! > 0) || (c.isPercentBudget && c.budgetPercent != null && c.budgetPercent! > 0))).toList();
        final unbudgeted = categories.where((c) => c.type == TransactionType.expense && !((c.budget != null && c.budget! > 0) || (c.isPercentBudget && c.budgetPercent != null && c.budgetPercent! > 0))).toList();

        // Calculate totals
        double totalBudget = 0;
        double totalSpent = 0;
        for (var cat in budgeted) {
          totalBudget += resolvedBudget(cat);
          totalSpent += stats.categorySpending[cat.id] ?? 0;
        }
        final overallProgress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
        final overallPercent = totalBudget > 0 ? (totalSpent / totalBudget * 100).toStringAsFixed(0) : '0';

        return Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: categories.where((c) => c.type == TransactionType.expense).isEmpty
                  ? _buildEmptyState(context)
                  : RefreshIndicator(
                      onRefresh: () {
                        HapticService.light();
                        return ref.read(transactionProvider.notifier).loadTransactions();
                      },
                      color: AppTheme.primaryColor(context),
                      backgroundColor: AppTheme.surfaceColor(context),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Summary card
                            if (budgeted.isNotEmpty)
                              _buildSummaryCard(
                                context,
                                totalBudget: totalBudget,
                                totalSpent: totalSpent,
                                progress: overallProgress,
                                percent: overallPercent,
                                currency: currency,
                              ).animate().fade(duration: 400.ms).slideY(begin: 0.08),

                          if (budgeted.isNotEmpty) const Gap(28),

                          // Active budgets section
                          if (budgeted.isNotEmpty) ...[
                            Text(
                              'Active Budgets',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textColor(context),
                                letterSpacing: -0.3,
                              ),
                            ).animate().fade(delay: 100.ms),
                            const Gap(12),
                            ...budgeted.asMap().entries.map((entry) {
                              final index = entry.key;
                              final category = entry.value;
                              final spent = stats.categorySpending[category.id] ?? 0;
                              return _buildBudgetCard(
                                context,
                                ref,
                                category: category,
                                spent: spent,
                                currency: currency,
                                index: index,
                                resolvedBudget: resolvedBudget(category),
                                totalIncome: totalIncome,
                              ).animate().fade(delay: (150 + index * 60).ms).slideY(begin: 0.06);
                            }),
                            if (unbudgeted.isNotEmpty) const Gap(24),
                          ],

                          // Unbudgeted categories section
                          if (unbudgeted.isNotEmpty) ...[
                            Text(
                              budgeted.isEmpty ? 'Set Monthly Budgets' : 'Add More Budgets',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textColor(context),
                                letterSpacing: -0.3,
                              ),
                            ).animate().fade(delay: budgeted.isEmpty ? 100.ms : 300.ms),
                            if (budgeted.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Tap a category to set a spending limit',
                                  style: TextStyle(
                                    color: AppTheme.textLightColor(context),
                                    fontSize: 13,
                                  ),
                                ),
                              ).animate().fade(delay: 150.ms),
                            const Gap(12),
                            Builder(
                              builder: (context) {
                                final screenWidth = MediaQuery.of(context).size.width;
                                final maxRowWidth = screenWidth - 40; // 20 padding each side
                                const spacing = 10.0;

                                double estimateWidth(String text) {
                                  return 92.0 + (text.length * 7.5);
                                }

                                final pendingItems = <Map<String, dynamic>>[];
                                for (int i = 0; i < unbudgeted.length; i++) {
                                   pendingItems.add({
                                     'category': unbudgeted[i],
                                     'width': estimateWidth(unbudgeted[i].name),
                                     'isManage': false,
                                     'originalIndex': i,
                                   });
                                }
                                pendingItems.add({
                                   'category': null,
                                   'width': estimateWidth('Manage'),
                                   'isManage': true,
                                   'originalIndex': unbudgeted.length,
                                });

                                final optimallyOrderedItems = <Map<String, dynamic>>[];

                                while (pendingItems.isNotEmpty) {
                                  // Take the first remaining item
                                  final firstItem = pendingItems.removeAt(0);
                                  optimallyOrderedItems.add(firstItem);
                                  double currentX = firstItem['width'] as double;

                                  // repeatedly look ahead for the largest item that still fits on this row
                                  bool found = true;
                                  while (found) {
                                    found = false;
                                    int bestIndex = -1;
                                    double bestWidth = -1;
                                    
                                    for (int i = 0; i < pendingItems.length; i++) {
                                      final w = pendingItems[i]['width'] as double;
                                      if (currentX + spacing + w <= maxRowWidth) {
                                        if (w > bestWidth) {
                                          bestWidth = w;
                                          bestIndex = i;
                                        }
                                      }
                                    }
                                    
                                    if (bestIndex != -1) {
                                      final fitItem = pendingItems.removeAt(bestIndex);
                                      optimallyOrderedItems.add(fitItem);
                                      currentX += spacing + bestWidth;
                                      found = true;
                                    }
                                  }
                                }

                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: 10,
                                  children: optimallyOrderedItems.map((item) {
                                    if (item['isManage'] == true) {
                                      return _buildManageChip(context, budgeted.isEmpty, item['originalIndex']);
                                    } else {
                                      final category = item['category'] as TransactionCategory;
                                      return _buildUnbudgetedChip(context, ref, category, currency, totalIncome)
                                          .animate()
                                          .fade(delay: ((budgeted.isEmpty ? 200 : 350) + item['originalIndex'] * 50).ms)
                                          .scale(begin: const Offset(0.92, 0.92));
                                    }
                                  }).toList(),
                                );
                              },
                            ),
                          ],

                          // If unbudgeted is empty but we have expense categories, show the Manage button
                          if (unbudgeted.isEmpty && categories.where((c) => c.type == TransactionType.expense).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    HapticService.light();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const CategoryManagerScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.settings_outlined, size: 16),
                                  label: const Text('Manage Categories'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.textLightColor(context),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ],
          );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Budgets',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.textColor(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: () {
              HapticService.light();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoryManagerScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: const Alignment(0, -0.3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined, size: 56, color: AppTheme.primaryColor(context).withValues(alpha: 0.6)),
                  ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),
                  const SizedBox(height: 24),
                  Text(
                    'No categories yet',
                    style: TextStyle(color: AppTheme.textColor(context), fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ).animate().slideY(begin: 0.2, delay: 300.ms, duration: 400.ms).fadeIn(),
                  const SizedBox(height: 8),
                  Text(
                    'Create categories first to set budgets',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 14),
                  ).animate().slideY(begin: 0.2, delay: 400.ms, duration: 400.ms).fadeIn(),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: AppTheme.primaryGradient(context),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticService.medium();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CategoryDetailScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: const Text('Create Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ).animate().slideY(begin: 0.2, delay: 500.ms, duration: 400.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required double totalBudget,
    required double totalSpent,
    required double progress,
    required String percent,
    required currency,
  }) {
    final isOver = totalSpent > totalBudget;
    final remaining = totalBudget - totalSpent;
    final fmt = NumberFormat.currency(symbol: currency.symbol);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Budget',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      fmt.format(totalBudget),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isOver
                      ? Colors.red.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    color: isOver ? const Color(0xFFFFCDD2) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const Gap(20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? const Color(0xFFFF8A80) : Colors.white,
              ),
            ),
          ),
          const Gap(14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent ${fmt.format(totalSpent)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                isOver
                    ? 'Over by ${fmt.format(totalSpent - totalBudget)}'
                    : '${fmt.format(remaining)} left',
                style: TextStyle(
                  color: isOver
                      ? const Color(0xFFFFCDD2)
                      : Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    WidgetRef ref, {
    required TransactionCategory category,
    required double spent,
    required currency,
    required int index,
    required double resolvedBudget,
    required double totalIncome,
  }) {
    final budget = resolvedBudget;
    final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final percent = budget > 0 ? (spent / budget * 100).toStringAsFixed(0) : '0';
    final isOver = spent > budget;
    final remaining = budget - spent;
    final fmt = NumberFormat.currency(symbol: currency.symbol);
    final isPercent = category.isPercentBudget;

    return GestureDetector(
      onTap: () {
        HapticService.light();
        _showEditBudgetSheet(context, ref, category, currency, totalIncome);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dividerColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    IconUtils.getIcon(category.iconCodePoint),
                    color: category.color,
                    size: 20,
                  ),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              category.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPercent) ...[
                            const Gap(8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: category.color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${category.budgetPercent?.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: category.color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Gap(2),
                      Text(
                        isOver
                            ? 'Exceeded by ${fmt.format(spent - budget)}'
                            : '${fmt.format(remaining)} remaining',
                        style: TextStyle(
                          color: isOver
                              ? AppTheme.expenseColor(context)
                              : AppTheme.textLightColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isOver
                        ? AppTheme.expenseColor(context).withValues(alpha: 0.12)
                        : category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$percent%',
                    style: TextStyle(
                      color: isOver ? AppTheme.expenseColor(context) : category.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppTheme.dividerColor(context),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? AppTheme.errorColor(context) : category.color,
                ),
              ),
            ),
            const Gap(10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fmt.format(spent),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                Text(
                  'of ${fmt.format(budget)}',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnbudgetedChip(
    BuildContext context,
    WidgetRef ref,
    TransactionCategory category,
    currency,
    double totalIncome,
  ) {
    return GestureDetector(
      onTap: () {
        HapticService.light();
        _showEditBudgetSheet(context, ref, category, currency, totalIncome);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                IconUtils.getIcon(category.iconCodePoint),
                color: category.color,
                size: 16,
              ),
            ),
            const Gap(10),
            Flexible(
              child: Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(8),
            Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageChip(BuildContext context, bool isBudgetedEmpty, int unbudgetedLength) {
    return GestureDetector(
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CategoryManagerScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 16,
                color: AppTheme.primaryColor(context),
              ),
            ),
            const Gap(10),
            const Flexible(
              child: Text(
                'Manage',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    ).animate()
      .fade(delay: ((isBudgetedEmpty ? 200 : 350) + unbudgetedLength * 50).ms)
      .scale(begin: const Offset(0.92, 0.92));
  }

  void _showEditBudgetSheet(
    BuildContext context,
    WidgetRef ref,
    TransactionCategory category,
    currency,
    double totalIncome,
  ) {
    final hasBudget = (category.budget != null && category.budget! > 0) || (category.isPercentBudget && category.budgetPercent != null && category.budgetPercent! > 0);

    HapticService.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool isPercentMode = category.isPercentBudget;
        String currentExpression;
        if (isPercentMode && category.budgetPercent != null && category.budgetPercent! > 0) {
          currentExpression = category.budgetPercent!.toStringAsFixed(0);
        } else if (!isPercentMode && category.budget != null && category.budget! > 0) {
          currentExpression = category.budget!.toStringAsFixed(0);
        } else {
          currentExpression = '';
        }
        String currentResult = currentExpression;

        return StatefulBuilder(
          builder: (context, setState) {
            final fmt = NumberFormat.currency(symbol: currency.symbol);
            double? resolvedAmount;
            if (isPercentMode && currentResult.isNotEmpty) {
              final pct = double.tryParse(currentResult);
              if (pct != null && pct > 0) {
                resolvedAmount = totalIncome * pct / 100;
              }
            }

            return Padding(
              padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(20),
              // Category header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        IconUtils.getIcon(category.iconCodePoint),
                        color: category.color,
                        size: 24,
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            hasBudget ? 'Edit monthly budget' : 'Set monthly budget',
                            style: TextStyle(
                              color: AppTheme.textLightColor(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasBudget)
                      IconButton(
                        onPressed: () async {
                          HapticService.selection();
                          final confirmed = await ConfirmationSheet.show(
                            context: context,
                            title: 'Remove Budget?',
                            description: 'Are you sure you want to remove the monthly budget for ${category.name}?',
                            confirmLabel: 'Remove',
                            confirmColor: AppTheme.expenseColor(context),
                            icon: Icons.delete_sweep_rounded,
                            isDanger: true,
                          );

                          if (confirmed == true) {
                            HapticService.heavy();
                            _saveBudget(
                              ref,
                              category,
                              budget: null,
                              budgetPercent: null,
                              isPercentBudget: false,
                            );
                            if (context.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          }
                        },
                        icon: Icon(Icons.delete_outline_rounded, color: AppTheme.expenseColor(context)),
                        tooltip: 'Remove Budget',
                      ),
                  ],
                ),
              ),
              const Gap(20),
              // Fixed / % of Income toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLightColor(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticService.selection();
                            if (isPercentMode) {
                              setState(() {
                                isPercentMode = false;
                                currentExpression = '';
                                currentResult = '';
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isPercentMode
                                  ? AppTheme.primaryColor(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Fixed Amount',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: !isPercentMode
                                    ? Colors.white
                                    : AppTheme.textLightColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticService.selection();
                            if (!isPercentMode) {
                              setState(() {
                                isPercentMode = true;
                                currentExpression = '';
                                currentResult = '';
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isPercentMode
                                  ? AppTheme.primaryColor(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '% of Income',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isPercentMode
                                    ? Colors.white
                                    : AppTheme.textLightColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(20),
              // Amount / Percentage display
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPercentMode ? '' : '${currency.symbol} ',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: AppTheme.textLightColor(context),
                        ),
                      ),
                      Text(
                        currentExpression.isEmpty ? '0' : currentExpression,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: currentExpression.isEmpty
                              ? AppTheme.textLightColor(context).withValues(alpha: 0.3)
                              : AppTheme.textColor(context),
                        ),
                      ),
                      if (isPercentMode)
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: currentExpression.isEmpty
                                ? AppTheme.textLightColor(context).withValues(alpha: 0.3)
                                : AppTheme.textLightColor(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Resolved amount preview (percentage mode)
              if (isPercentMode) ...[
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: resolvedAmount != null
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: category.color.withValues(alpha: 0.7)),
                                const Gap(8),
                                Text(
                                  '$currentResult% of ${fmt.format(totalIncome)} = ${fmt.format(resolvedAmount)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: category.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : totalIncome <= 0
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                              child: Text(
                                'No income recorded yet — budget will update when income is tracked',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textLightColor(context),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                ),
              ],
              const Gap(4),
              // Quick presets
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: isPercentMode
                      ? [5, 10, 15, 20, 25, 30].map((pct) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticService.light();
                                setState(() {
                                  currentExpression = pct.toString();
                                  currentResult = pct.toString();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: currentExpression == pct.toString()
                                      ? category.color.withValues(alpha: 0.15)
                                      : AppTheme.surfaceLightColor(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: currentExpression == pct.toString()
                                        ? category.color.withValues(alpha: 0.4)
                                        : AppTheme.dividerColor(context),
                                  ),
                                ),
                                child: Text(
                                  '$pct%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: currentExpression == pct.toString()
                                        ? category.color
                                        : AppTheme.textColor(context),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList()
                      : [100, 250, 500, 1000, 2500, 5000].map((amount) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticService.light();
                                setState(() {
                                  currentExpression = amount.toString();
                                  currentResult = amount.toString();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLightColor(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.dividerColor(context)),
                                ),
                                child: Text(
                                  '${currency.symbol}$amount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.textColor(context),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                ),
              ),
              const Gap(24),
              // NumPad
              NumPad(
                compact: true,
                initialValue: currentExpression,
                onValueChanged: (expr, res) {
                  setState(() {
                    currentExpression = expr;
                    currentResult = res;
                  });
                },
                onDone: () {
                  final value = double.tryParse(currentResult);
                  if (isPercentMode) {
                    _saveBudget(
                      ref,
                      category,
                      budget: null,
                      budgetPercent: (value == null || value == 0) ? null : value,
                      isPercentBudget: value != null && value > 0,
                    );
                  } else {
                    _saveBudget(
                      ref,
                      category,
                      budget: (value == null || value == 0) ? null : value,
                      budgetPercent: null,
                      isPercentBudget: false,
                    );
                  }
                  Navigator.pop(sheetContext);
                },
              ),
              const Gap(8),
            ],
          ),
        ),
      );
          },
        );
      },
    );
  }

  void _saveBudget(
    WidgetRef ref,
    TransactionCategory category, {
    double? budget,
    double? budgetPercent,
    required bool isPercentBudget,
  }) {
    HapticService.success();
    final notifier = ref.read(categoriesProvider.notifier);
    final updatedCategory = TransactionCategory(
      id: category.id,
      name: category.name,
      iconCodePoint: category.iconCodePoint,
      colorHex: category.colorHex,
      type: category.type,
      budget: budget,
      budgetPercent: budgetPercent,
      isPercentBudget: isPercentBudget,
    );
    notifier.editCategory(updatedCategory);
  }
}
