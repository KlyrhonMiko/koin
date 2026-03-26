import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/currency.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  int _selectedFilterIndex = 1; // 0: This Week, 1: This Month, 2: All Time

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionProvider);
    final categories = ref.watch(categoryProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(transactionProvider.notifier).loadTransactions(),
          color: AppTheme.primaryColor(context),
          backgroundColor: AppTheme.surfaceColor(context),
          child: transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: const Alignment(0, -0.3),
                        child: _buildEmptyStateContent(context, 'No expense data yet', 'Add some expenses to see your analysis', Icons.insights_rounded),
                      ),
                    ),
                  ],
                );
              }
              
              final now = DateTime.now();
              
              // Filter transactions based on selection (Expense only)
              List<AppTransaction> filteredTransactions = transactions.where((t) => t.type == TransactionType.expense).toList();
              
              if (_selectedFilterIndex == 0) {
                // This Week
                final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
                filteredTransactions = filteredTransactions.where((t) => t.date.isAfter(startOfWeekDate.subtract(const Duration(days: 1)))).toList();
              } else if (_selectedFilterIndex == 1) {
                // This Month
                filteredTransactions = filteredTransactions.where((t) {
                  return t.date.year == now.year && t.date.month == now.month;
                }).toList();
              }

              if (filteredTransactions.isEmpty) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      sliver: SliverToBoxAdapter(
                        child: _buildFilterTabs(context),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: const Alignment(0, -0.3),
                        child: _buildEmptyStateContent(context, 'No expense data yet', 'Add some expenses for this period to see your analysis', Icons.insights_rounded),
                      ),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterTabs(context).animate().fade(duration: 400.ms),
                    const Gap(24),
                    _buildSummaryCard(context, filteredTransactions, currency).animate().fade(delay: 100.ms).slideY(begin: 0.1),
                    const Gap(28),
                    Text(
                      'Expense Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textColor(context), letterSpacing: -0.3),
                    ).animate().fade(delay: 200.ms),
                    const Gap(16),
                    _buildPieChartSection(context, filteredTransactions, categories, currency).animate().fade(delay: 300.ms).scale(begin: const Offset(0.97, 0.97)),
                    const Gap(28),
                    Text(
                      'Category Spending',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textColor(context), letterSpacing: -0.3),
                    ).animate().fade(delay: 400.ms),
                    const Gap(16),
                    _buildTopCategoriesList(context, filteredTransactions, categories, currency).animate().fade(delay: 450.ms).slideY(begin: 0.1),
                  ],
                ),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildFilterTab(context, 'This Week', 0)),
          Expanded(child: _buildFilterTab(context, 'This Month', 1)),
          Expanded(child: _buildFilterTab(context, 'All Time', 2)),
        ],
      ),
    );
  }

  Widget _buildFilterTab(BuildContext context, String title, int index) {
    final isSelected = _selectedFilterIndex == index;
    final primaryColor = AppTheme.primaryColor(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textLightColor(context),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<AppTransaction> expenses, Currency currency) {
    double totalExpense = expenses.fold(0, (sum, t) => sum + t.amount);
    int count = expenses.length;
    double average = count > 0 ? totalExpense / count : 0;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: AppTheme.dangerGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.expenseColor(context).withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative Background Pattern
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Spent',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        currency.code,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                Text(
                  NumberFormat.currency(symbol: currency.symbol).format(totalExpense),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
                const Gap(24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transactions',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const Gap(6),
                          Text(
                            count.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 35, color: Colors.white.withValues(alpha: 0.2)),
                    const Gap(20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Avg / Tx',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const Gap(6),
                          Text(
                            NumberFormat.currency(symbol: currency.symbol).format(average),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection(BuildContext context, List<AppTransaction> expenses, List<TransactionCategory> categories, Currency currency) {
    Map<String, double> categorySpending = {};
    for (var tx in expenses) {
      categorySpending[tx.categoryId] = (categorySpending[tx.categoryId] ?? 0) + tx.amount;
    }

    if (categorySpending.isEmpty) return const SizedBox.shrink();

    // Sort by spending
    var sortedEntries = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int maxCategories = 5;
    List<PieChartSectionData> sections = [];
    double totalSpent = expenses.fold(0, (s, t) => s + t.amount);
    
    for (int i = 0; i < sortedEntries.length; i++) {
        var entry = sortedEntries[i];
        if (i >= maxCategories && sortedEntries.length > maxCategories + 1) {
             double othersValue = 0;
             for (int j = i; j < sortedEntries.length; j++) {
                 othersValue += sortedEntries[j].value;
             }
             sections.add(PieChartSectionData(
               color: Colors.grey.shade400,
               value: othersValue,
               title: '${((othersValue / totalSpent) * 100).toStringAsFixed(0)}%',
               radius: 45,
               titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
               badgeWidget: _buildLegendIcon(Icons.more_horiz, Colors.grey.shade600),
               badgePositionPercentageOffset: 1.15,
             ));
             break;
        } else {
             final category = categories.firstWhere((c) => c.id == entry.key, orElse: () => TransactionCategory(id: 'unknown', name: 'Unknown', iconCodePoint: Icons.help_outline.codePoint, colorHex: '#9E9E9E', type: TransactionType.expense));
             sections.add(PieChartSectionData(
               color: category.color,
               value: entry.value,
               title: '${((entry.value / totalSpent) * 100).toStringAsFixed(0)}%',
               radius: 45,
               titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
               badgeWidget: _buildLegendIcon(IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'), category.color),
               badgePositionPercentageOffset: 1.15,
             ));
        }
    }

    return Container(
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.dividerColor(context).withValues(alpha: 0.8)),
        boxShadow: [
           BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 6,
              centerSpaceRadius: 75,
              sections: sections,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_rounded, color: AppTheme.textLightColor(context).withValues(alpha: 0.4), size: 28),
              const Gap(8),
              Text(
                'Total',
                style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Gap(4),
              Text(
                NumberFormat.compactCurrency(symbol: currency.symbol).format(totalSpent),
                style: TextStyle(color: AppTheme.textColor(context), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ],
          ).animate().fade(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _buildLegendIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _buildTopCategoriesList(BuildContext context, List<AppTransaction> expenses, List<TransactionCategory> categories, Currency currency) {
    Map<String, double> categorySpending = {};
    for (var tx in expenses) {
      categorySpending[tx.categoryId] = (categorySpending[tx.categoryId] ?? 0) + tx.amount;
    }

    if (categorySpending.isEmpty) return const SizedBox.shrink();

    var sortedEntries = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    double totalSpent = expenses.fold(0, (s, t) => s + t.amount);

    int rank = 1;
    return Column(
      children: sortedEntries.map((entry) {
        final category = categories.firstWhere((c) => c.id == entry.key, orElse: () => TransactionCategory(id: 'unknown', name: 'Unknown', iconCodePoint: Icons.help_outline.codePoint, colorHex: '#9E9E9E', type: TransactionType.expense));
        final percent = (entry.value / totalSpent) * 100;
        final currentRank = rank++;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.dividerColor(context).withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '#$currentRank',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const Gap(4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
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
                    Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const Gap(8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 6,
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: percent / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: [
                                  category.color.withValues(alpha: 0.5),
                                  category.color,
                                ],
                              ),
                            ),
                          ),
                        ).animate().scaleX(alignment: Alignment.centerLeft, duration: 800.ms, curve: Curves.easeOutCirc),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   TweenAnimationBuilder<double>(
                     tween: Tween<double>(begin: 0, end: entry.value),
                     duration: const Duration(milliseconds: 1000),
                     curve: Curves.easeOutCirc,
                     builder: (context, value, child) {
                       return Text(
                          NumberFormat.currency(symbol: currency.symbol).format(value),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5),
                       );
                     },
                   ),
                   const Gap(4),
                   Text(
                     '${percent.toStringAsFixed(1)}%',
                     style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 13, fontWeight: FontWeight.w600),
                   ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyStateContent(BuildContext context, String title, String subtitle, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Keep column compact
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
          child: Icon(icon, size: 56, color: AppTheme.primaryColor(context).withValues(alpha: 0.6)),
        ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),
        const SizedBox(height: 24),
        Text(
          title,
          style: TextStyle(color: AppTheme.textColor(context), fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ).animate().slideY(begin: 0.2, delay: 300.ms, duration: 400.ms).fadeIn(),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 14),
          textAlign: TextAlign.center,
        ).animate().slideY(begin: 0.2, delay: 400.ms, duration: 400.ms).fadeIn(),
      ],
    );
  }
}
