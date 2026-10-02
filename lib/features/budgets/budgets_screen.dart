import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/categories/categories.dart';
import 'widgets/budget_editor_sheet.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider);
    final stats = ref.watch(monthlyDashboardStatsProvider(_selectedMonth));
    final currency = settings.currency;

    final overview = ref.watch(monthlyBudgetOverviewProvider(_selectedMonth));
    final budgeted = overview.budgetedCategories;
    final unbudgeted = overview.unbudgetedCategories;
    final totalBudget = overview.totalBudget;
    final totalSpent = overview.totalSpent;
    final overallProgress = overview.overallProgress;
    final overallPercent = overview.overallPercent;
    final totalIncome = stats.totalIncome;

    return categoriesAsync.when(
      data: (categories) {
        return Column(
          children: [
            _buildHeader(context),
            Expanded(
              child:
                  categories
                      .where((c) => c.type == TransactionType.expense)
                      .isEmpty
                  ? _buildEmptyState(context)
                  : RefreshIndicator(
                      onRefresh: () {
                        HapticService.light();
                        return ref
                            .read(transactionProvider.notifier)
                            .loadTransactions();
                      },
                      color: AppTheme.primaryColor(context),
                      backgroundColor: AppTheme.surfaceColor(context),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          KoinSpacing.screenInset,
                          16,
                          KoinSpacing.screenInset,
                          100,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children:
                              [
                                    // Summary card
                                    if (budgeted.isNotEmpty)
                                      _buildSummaryCard(
                                        context,
                                        totalBudget: totalBudget,
                                        totalSpent: totalSpent,
                                        progress: overallProgress,
                                        percent: overallPercent,
                                        currency: currency,
                                      ),

                                    if (budgeted.isNotEmpty)
                                      const Gap(KoinSpacing.sectionGap),

                                    // Active budgets section
                                    if (budgeted.isNotEmpty) ...[
                                      Text(
                                        'Active Budgets',
                                        style: TextStyle(
                                          fontSize: KoinTypography.sectionTitle,
                                          fontWeight:
                                              KoinTypography.headingWeight,
                                          color: AppTheme.textColor(context),
                                          letterSpacing:
                                              KoinTypography.headingTracking,
                                        ),
                                      ),
                                      const Gap(12),
                                      ...budgeted.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final category = entry.value;
                                        final metrics = overview
                                            .metricsByCategory[category.id];
                                        if (metrics == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return _buildBudgetCard(
                                          context,
                                          ref,
                                          metrics: metrics,
                                          currency: currency,
                                          index: index,
                                          totalIncome: totalIncome,
                                        );
                                      }),
                                      if (unbudgeted.isNotEmpty) const Gap(24),
                                    ],

                                    // Unbudgeted categories section
                                    if (unbudgeted.isNotEmpty) ...[
                                      Text(
                                        budgeted.isEmpty
                                            ? 'Set Monthly Budgets'
                                            : 'Add More Budgets',
                                        style: TextStyle(
                                          fontSize: KoinTypography.sectionTitle,
                                          fontWeight:
                                              KoinTypography.headingWeight,
                                          color: AppTheme.textColor(context),
                                          letterSpacing:
                                              KoinTypography.headingTracking,
                                        ),
                                      ),
                                      if (budgeted.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            'Tap a category to set a spending limit',
                                            style: TextStyle(
                                              color: AppTheme.textLightColor(
                                                context,
                                              ),
                                              fontSize: KoinTypography.caption,
                                            ),
                                          ),
                                        ),
                                      const Gap(12),
                                      Builder(
                                        builder: (context) {
                                          final screenWidth = MediaQuery.of(
                                            context,
                                          ).size.width;
                                          final maxRowWidth =
                                              screenWidth -
                                              40; // 20 padding each side
                                          const spacing = 10.0;

                                          final optimallyOrderedItems =
                                              UnbudgetedChipItem.optimizeRowPacking(
                                                unbudgeted: unbudgeted,
                                                maxRowWidth: maxRowWidth,
                                                spacing: spacing,
                                              );

                                          return Wrap(
                                            spacing: spacing,
                                            runSpacing: 10,
                                            children: optimallyOrderedItems
                                                .map((item) {
                                                  if (item.isManage) {
                                                    return _buildManageChip(
                                                      context,
                                                      budgeted.isEmpty,
                                                      item.originalIndex,
                                                    );
                                                  } else {
                                                    return _buildUnbudgetedChip(
                                                      context,
                                                      ref,
                                                      item.category!,
                                                      currency,
                                                      totalIncome,
                                                    );
                                                  }
                                                })
                                                .toList()
                                                .animate(interval: 40.ms)
                                                .fade(
                                                  duration: 250.ms,
                                                  curve: Curves.easeOutCubic,
                                                )
                                                .scale(
                                                  begin: const Offset(
                                                    0.95,
                                                    0.95,
                                                  ),
                                                  duration: 250.ms,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                          );
                                        },
                                      ),
                                    ],

                                    // If unbudgeted is empty but we have expense categories, show the Manage button
                                    if (unbudgeted.isEmpty &&
                                        categories
                                            .where(
                                              (c) =>
                                                  c.type ==
                                                  TransactionType.expense,
                                            )
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Center(
                                          child: TextButton.icon(
                                            onPressed: () {
                                              HapticService.light();
                                              Navigator.push(
                                                context,
                                                SlideUpRoute(
                                                  page:
                                                      const CategoryManagerScreen(),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.settings_outlined,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Manage Categories',
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.textLightColor(
                                                    context,
                                                  ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    const Gap(32),
                                    Center(
                                      child: Container(
                                        width: 48,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: AppTheme.dividerColor(
                                            context,
                                          ).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Gap(64),
                                  ]
                                  .animate(interval: 40.ms)
                                  .fade(
                                    duration: 250.ms,
                                    curve: Curves.easeOutCubic,
                                  )
                                  .scale(
                                    begin: const Offset(0.95, 0.95),
                                    duration: 250.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
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
    return KoinScreenHeader(
      tag: 'STRATEGY',
      title: 'Monthly Budgets',
      backgroundColor: AppTheme.backgroundColor(context),
      trailing: IconButton(
        icon: const Icon(Icons.category_outlined),
        tooltip: 'Manage Categories',
        onPressed: () {
          HapticService.light();
          Navigator.push(
            context,
            SlideUpRoute(page: const CategoryManagerScreen()),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return KoinEmptyState.sliver(
      alignment: const Alignment(0, -0.3),
      icon: Icons.account_balance_wallet_outlined,
      title: 'No categories yet',
      subtitle: 'Create categories first to set budgets',
      action: SizedBox(
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
                SlideUpRoute(page: const CategoryDetailScreen()),
              );
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Create Category',
              style: TextStyle(
                color: Colors.white,
                fontWeight: KoinTypography.titleWeight,
                fontSize: KoinTypography.body,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineMonthSelector({bool isDark = false}) {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final textColor = isDark ? AppTheme.textColor(context) : Colors.white;
    final chevronColor = isDark ? AppTheme.textColor(context) : Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticService.selection();
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Icon(
              Icons.chevron_left_rounded,
              color: chevronColor,
              size: 18,
            ),
          ),
        ),
        const Gap(6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isCurrentMonth
              ? null
              : () {
                  HapticService.selection();
                  setState(() {
                    _selectedMonth = DateTime(now.year, now.month);
                  });
                },
          child: Text(
            monthLabel,
            style: TextStyle(
              color: textColor,
              fontSize: KoinTypography.caption,
              fontWeight: KoinTypography.titleWeight,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const Gap(6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isCurrentMonth
              ? null
              : () {
                  HapticService.selection();
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                  });
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Icon(
              Icons.chevron_right_rounded,
              color: chevronColor.withValues(alpha: isCurrentMonth ? 0.4 : 1.0),
              size: 18,
            ),
          ),
        ),
      ],
    ).animate().fade(delay: 150.ms);
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

    return KoinSummaryCard(
      shapeStyle: SummaryShapeStyle.budgets,
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Budget',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: KoinTypography.caption,
                        fontWeight: KoinTypography.labelWeight,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Gap(4),
                    AnimatedCounter(
                      value: totalBudget,
                      formatter: (v) => fmt.format(v),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: KoinTypography.summaryAmount,
                        fontWeight: KoinTypography.headingWeight,
                        letterSpacing: KoinTypography.amountTracking,
                        height: KoinTypography.amountHeight,
                      ),
                    ),
                    const Gap(16),
                    Transform.translate(
                      offset: const Offset(-6, 0),
                      child: _buildInlineMonthSelector(),
                    ),
                  ],
                ),
              ),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOver
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) {
                      final targetPercent = double.tryParse(percent) ?? 0;
                      final displayPercent =
                          (targetPercent *
                                  (progress > 0 ? (val / progress) : 0))
                              .round();
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 6,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: CircularProgressIndicator(
                              value: val,
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                              color: isOver
                                  ? const Color(0xFFFF8A80)
                                  : Colors.white,
                            ),
                          ),
                          Text(
                            '$displayPercent%',
                            style: TextStyle(
                              color: isOver
                                  ? const Color(0xFFFFCDD2)
                                  : Colors.white,
                              fontSize: KoinTypography.itemTitle,
                              fontWeight: KoinTypography.headingWeight,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const Gap(24),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
          const Gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: KoinTypography.small,
                      fontWeight: KoinTypography.labelWeight,
                    ),
                  ),
                  const Gap(4),
                  AnimatedCounter(
                    value: totalSpent,
                    formatter: (v) => fmt.format(v),
                    style: TextStyle(
                      color: isOver ? const Color(0xFFFFCDD2) : Colors.white,
                      fontSize: KoinTypography.body,
                      fontWeight: KoinTypography.titleWeight,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isOver ? 'Over Budget' : 'Remaining',
                    style: TextStyle(
                      color: isOver
                          ? const Color(0xFFFFCDD2)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: KoinTypography.small,
                      fontWeight: KoinTypography.labelWeight,
                    ),
                  ),
                  const Gap(4),
                  AnimatedCounter(
                    value: isOver ? (totalSpent - totalBudget) : remaining,
                    formatter: (v) => fmt.format(v),
                    style: TextStyle(
                      color: isOver ? const Color(0xFFFFCDD2) : Colors.white,
                      fontSize: KoinTypography.body,
                      fontWeight: KoinTypography.titleWeight,
                    ),
                  ),
                ],
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
    required CategoryBudgetMetrics metrics,
    required currency,
    required int index,
    required double totalIncome,
  }) {
    final category = metrics.category;
    final budget = metrics.budget;
    final spent = metrics.spent;
    final progress = metrics.progress;
    final percent = metrics.percent.toStringAsFixed(0);
    final isOver = metrics.isOverBudget;
    final fmt = NumberFormat.currency(symbol: currency.symbol);
    final isPercent = category.isPercentBudget;

    return PressableScale(
      onTap: () {
        BudgetEditorSheet.show(
          context,
          category: category,
          currency: currency,
          totalIncome: totalIncome,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dividerColor(context)),
          boxShadow: [
            if (isOver)
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.08),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
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
                              style: const TextStyle(
                                fontWeight: KoinTypography.titleWeight,
                                fontSize: KoinTypography.body,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPercent) ...[
                            const Gap(8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${category.budgetPercent}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor(context),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Gap(4),
                      Row(
                        children: [
                          AnimatedCounter(
                            value: spent,
                            formatter: (v) => fmt.format(v),
                            style: TextStyle(
                              fontSize: KoinTypography.caption,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.6),
                              fontWeight: KoinTypography.supportingWeight,
                            ),
                          ),
                          Text(
                            ' / ',
                            style: TextStyle(
                              fontSize: KoinTypography.caption,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          AnimatedCounter(
                            value: budget,
                            formatter: (v) => fmt.format(v),
                            style: TextStyle(
                              fontSize: KoinTypography.caption,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.8),
                              fontWeight: KoinTypography.labelWeight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isOver
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppTheme.surfaceLightColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedCounter(
                        value: double.tryParse(percent) ?? 0,
                        formatter: (v) => '${v.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: isOver
                              ? Colors.red
                              : AppTheme.textLightColor(context),
                          fontWeight: KoinTypography.titleWeight,
                          fontSize: KoinTypography.caption,
                        ),
                      ),
                    )
                    .animate(
                      onPlay: (controller) =>
                          isOver ? controller.repeat(reverse: true) : null,
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                      duration: 800.ms,
                      curve: Curves.easeInOut,
                    ),
              ],
            ),
            const Gap(16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: Duration(milliseconds: 700 + (index * 100)),
                curve: Curves.easeOutCubic,
                builder: (context, animatedProgress, _) {
                  return LinearProgressIndicator(
                    value: animatedProgress,
                    minHeight: 6,
                    backgroundColor: AppTheme.dividerColor(
                      context,
                    ).withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOver ? Colors.red : category.color,
                    ),
                  );
                },
              ),
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
    return PressableScale(
      onTap: () {
        BudgetEditorSheet.show(
          context,
          category: category,
          currency: currency,
          totalIncome: totalIncome,
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
                style: const TextStyle(
                  fontWeight: KoinTypography.labelWeight,
                  fontSize: KoinTypography.caption,
                ),
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

  Widget _buildManageChip(
    BuildContext context,
    bool isBudgetedEmpty,
    int unbudgetedLength,
  ) {
    return GestureDetector(
          onTap: () {
            HapticService.light();
            Navigator.push(
              context,
              SlideUpRoute(page: const CategoryManagerScreen()),
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
                    color: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.12),
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fade(delay: ((isBudgetedEmpty ? 200 : 350) + unbudgetedLength * 50).ms)
        .scale(begin: const Offset(0.92, 0.92));
  }
}
