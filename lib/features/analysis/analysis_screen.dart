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
  int _selectedFilterIndex = 0; // 0: All Time, 1: This Month

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionProvider);
    final categories = ref.watch(categoryProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: SizedBox.shrink(),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(transactionProvider.notifier).loadTransactions(),
          color: AppTheme.primaryColor(context),
          backgroundColor: AppTheme.surfaceColor(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return _buildEmptyState(context);
                }
                
                final now = DateTime.now();
                
                // Filter transactions based on selection
                List<AppTransaction> filteredTransactions = transactions.where((t) => t.type == TransactionType.expense).toList();
                
                if (_selectedFilterIndex == 1) {
                  filteredTransactions = filteredTransactions.where((t) {
                    return t.date.year == now.year && t.date.month == now.month;
                  }).toList();
                }

                if (filteredTransactions.isEmpty) {
                   return Column(
                     children: [
                       _buildFilterTabs(context),
                       const Gap(40),
                       _buildEmptyState(context),
                     ],
                   );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterTabs(context).animate().fade(duration: 400.ms),
                    const Gap(24),
                    _buildSummaryCard(context, filteredTransactions, currency).animate().fade(delay: 100.ms).slideY(begin: 0.1),
                    const Gap(28),
                    Text(
                      'Expense Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textColor(context), letterSpacing: -0.3),
                    ).animate().fade(delay: 200.ms),
                    const Gap(16),
                    _buildPieChartSection(context, filteredTransactions, categories, currency).animate().fade(delay: 300.ms).scale(begin: const Offset(0.97, 0.97)),
                    const Gap(28),
                    Text(
                      'Category Spending',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textColor(context), letterSpacing: -0.3),
                    ).animate().fade(delay: 400.ms),
                    const Gap(16),
                    _buildTopCategoriesList(context, filteredTransactions, categories, currency).animate().fade(delay: 450.ms).slideY(begin: 0.1),
                  ],
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildFilterTab(context, 'All Time', 0)),
          Expanded(child: _buildFilterTab(context, 'This Month', 1)),
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textLightColor(context),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<AppTransaction> expenses, Currency currency) {
    double totalExpense = expenses.fold(0, (sum, t) => sum + t.amount);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppTheme.dangerGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.expenseColor(context).withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Spent',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currency.code,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const Gap(16),
          Text(
            NumberFormat.currency(symbol: currency.symbol).format(totalExpense),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
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

    // Allow up to top 5 colored clearly, rest grouped to "Others" if many
    int maxCategories = 5;
    List<PieChartSectionData> sections = [];
    double totalSpent = expenses.fold(0, (s, t) => s + t.amount);
    
    // We will use category defined colors instead
    for (int i = 0; i < sortedEntries.length; i++) {
        var entry = sortedEntries[i];
        if (i >= maxCategories && sortedEntries.length > maxCategories + 1) {
             // Let's compute others later if we want to group, but let's just show top 5 and group rest
             double othersValue = 0;
             for (int j = i; j < sortedEntries.length; j++) {
                 othersValue += sortedEntries[j].value;
             }
             sections.add(PieChartSectionData(
               color: Colors.grey,
               value: othersValue,
               title: '${((othersValue / totalSpent) * 100).toStringAsFixed(0)}%',
               radius: 35,
               titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
               badgeWidget: _buildLegendIcon(Icons.more_horiz, Colors.grey),
               badgePositionPercentageOffset: 1.15,
             ));
             break;
        } else {
             final category = categories.firstWhere((c) => c.id == entry.key, orElse: () => TransactionCategory(id: 'unknown', name: 'Unknown', iconCodePoint: Icons.help_outline.codePoint, colorHex: '#9E9E9E'));
             sections.add(PieChartSectionData(
               color: category.color,
               value: entry.value,
               title: '${((entry.value / totalSpent) * 100).toStringAsFixed(0)}%',
               radius: 35,
               titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
               badgeWidget: _buildLegendIcon(IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'), category.color),
               badgePositionPercentageOffset: 1.15,
             ));
        }
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 60,
          sections: sections,
          pieTouchData: PieTouchData(enabled: false),
        ),
      ),
    );
  }

  Widget _buildLegendIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 14),
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

    return Column(
      children: sortedEntries.map((entry) {
        final category = categories.firstWhere((c) => c.id == entry.key, orElse: () => TransactionCategory(id: 'unknown', name: 'Unknown', iconCodePoint: Icons.help_outline.codePoint, colorHex: '#9E9E9E'));
        final percent = (entry.value / totalSpent) * 100;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.dividerColor(context)),
          ),
          child: Row(
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
                    Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Gap(6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        backgroundColor: AppTheme.dividerColor(context),
                        valueColor: AlwaysStoppedAnimation<Color>(category.color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                      NumberFormat.currency(symbol: currency.symbol).format(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                   ),
                   const Gap(2),
                   Text(
                     '${percent.toStringAsFixed(1)}%',
                     style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 13, fontWeight: FontWeight.w500),
                   ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_outlined, size: 64, color: AppTheme.textLightColor(context).withValues(alpha: 0.3)),
          const Gap(16),
          Text(
            'No expense data yet',
            style: TextStyle(color: AppTheme.textLightColor(context), fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const Gap(8),
          Text(
            'Add some expenses to see your analysis',
            style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.7), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
