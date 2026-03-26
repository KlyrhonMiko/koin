import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/features/categories/category_manager_screen.dart';
import 'package:koin/features/categories/category_detail_screen.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);
    final settings = ref.watch(settingsProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final currency = settings.currency;

    final budgeted = categories.where((c) => c.budget != null && c.budget! > 0).toList();
    final unbudgeted = categories.where((c) => c.budget == null || c.budget == 0).toList();

    // Calculate totals
    double totalBudget = 0;
    double totalSpent = 0;
    for (var cat in budgeted) {
      totalBudget += cat.budget!;
      totalSpent += stats.categorySpending[cat.id] ?? 0;
    }
    final overallProgress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final overallPercent = totalBudget > 0 ? (totalSpent / totalBudget * 100).toStringAsFixed(0) : '0';

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoryManagerScreen()),
              );
            },
          ),
          const Gap(8),
        ],
      ),
      body: categories.isEmpty
          ? _buildEmptyState(context)
          : SingleChildScrollView(
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
                      ).animate().fade(delay: (150 + index * 60).ms).slideY(begin: 0.06);
                    }),
                    const Gap(24),
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
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ...unbudgeted.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value;
                          return _buildUnbudgetedChip(context, ref, category, currency)
                              .animate()
                              .fade(delay: ((budgeted.isEmpty ? 200 : 350) + index * 50).ms)
                              .scale(begin: const Offset(0.92, 0.92));
                        }),
                        // Manage categories "button" chip
                        GestureDetector(
                          onTap: () {
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
                                const Text(
                                  'Manage',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
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
                            .fade(delay: ((budgeted.isEmpty ? 200 : 350) + unbudgeted.length * 50).ms)
                            .scale(begin: const Offset(0.92, 0.92)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 52,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
            ),
          ),
          const Gap(24),
          Text(
            'No categories yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textLightColor(context),
            ),
          ),
          const Gap(6),
          Text(
            'Create categories first to set budgets',
            style: TextStyle(
              color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const Gap(24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoryDetailScreen()),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Category'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
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
  }) {
    final budget = category.budget!;
    final progress = (spent / budget).clamp(0.0, 1.0);
    final percent = (spent / budget * 100).toStringAsFixed(0);
    final isOver = spent > budget;
    final remaining = budget - spent;
    final fmt = NumberFormat.currency(symbol: currency.symbol);

    return GestureDetector(
      onTap: () => _showEditBudgetSheet(context, ref, category, currency),
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
                    IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                    color: category.color,
                    size: 20,
                  ),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
  ) {
    return GestureDetector(
      onTap: () => _showEditBudgetSheet(context, ref, category, currency),
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
                IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                color: category.color,
                size: 16,
              ),
            ),
            const Gap(10),
            Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

  void _showEditBudgetSheet(
    BuildContext context,
    WidgetRef ref,
    TransactionCategory category,
    currency,
  ) {
    final controller = TextEditingController(
      text: category.budget != null && category.budget! > 0
          ? category.budget!.toStringAsFixed(0)
          : '',
    );
    final hasBudget = category.budget != null && category.budget! > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
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
                ],
              ),
              const Gap(24),
              // Amount input
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: '${currency.symbol} ',
                  prefixStyle: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppTheme.textLightColor(context),
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              const Gap(16),
              // Quick presets
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [100, 250, 500, 1000, 2500, 5000].map((amount) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => controller.text = amount.toString(),
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
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());
                    _saveBudget(ref, category, value == 0 ? null : value);
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value != null && value > 0
                              ? '${category.name} budget updated'
                              : '${category.name} budget removed',
                        ),
                      ),
                    );
                  },
                  child: const Text('Save Budget'),
                ),
              ),
              // Remove budget button (only if editing existing)
              if (hasBudget) ...[
                const Gap(8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      _saveBudget(ref, category, null);
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${category.name} budget removed')),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.expenseColor(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Remove Budget',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }

  void _saveBudget(WidgetRef ref, TransactionCategory category, double? budget) {
    final notifier = ref.read(categoryProvider.notifier);
    final updatedCategory = TransactionCategory(
      id: category.id,
      name: category.name,
      iconCodePoint: category.iconCodePoint,
      colorHex: category.colorHex,
      budget: budget,
    );
    notifier.editCategory(updatedCategory);
  }
}
