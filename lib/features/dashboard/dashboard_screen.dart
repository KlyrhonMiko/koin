import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:koin/core/models/currency.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/features/settings/settings_screen.dart';
import 'package:koin/core/providers/navigation_provider.dart';
import 'package:koin/core/providers/category_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final transactionsAsync = ref.watch(transactionProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(transactionProvider.notifier).loadTransactions(),
          color: AppTheme.primaryColor(context),
          backgroundColor: AppTheme.surfaceColor(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(context).animate().fade(duration: 400.ms),
                const Gap(24),
                _buildBalanceCard(context, stats, currency).animate().fade(duration: 500.ms).slideY(begin: 0.08),
                const Gap(20),
                _buildAccountsList(context, stats, currency).animate().fade(delay: 100.ms).slideY(begin: 0.08),
                const Gap(20),
                _buildIncomeExpenseRow(context, stats, currency).animate().fade(delay: 150.ms).slideY(begin: 0.08),
                const Gap(28),
                _buildBudgetSection(context, ref, stats, currency).animate().fade(delay: 200.ms).slideY(begin: 0.08),
                const Gap(28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spending Overview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textColor(context), letterSpacing: -0.3),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(navigationProvider.notifier).setIndex(3);
                        ref.read(pageControllerProvider).animateToPage(
                          3,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        backgroundColor: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Full Analysis', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ).animate().fade(delay: 250.ms),
                const Gap(16),
                _buildChartSection(context, stats, currency).animate().fade(delay: 300.ms).scale(begin: const Offset(0.97, 0.97)),
                const Gap(28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textColor(context), letterSpacing: -0.3),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(navigationProvider.notifier).setIndex(1);
                        ref.read(pageControllerProvider).animateToPage(
                          1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        backgroundColor: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('View All', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ).animate().fade(delay: 350.ms),
                const Gap(12),
                _buildRecentTransactions(context, transactionsAsync, currency).animate().fade(delay: 400.ms).slideY(begin: 0.08),
                const Gap(100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(4),
            const Text(
              'Koin Tracker',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLightColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.dividerColor(context)),
            ),
            child: Icon(Icons.settings_outlined, color: AppTheme.textLightColor(context), size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsList(BuildContext context, DashboardStats stats, Currency currency) {
    if (stats.accounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accounts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textColor(context), letterSpacing: -0.3),
        ),
        const Gap(12),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: stats.accounts.length,
            itemBuilder: (context, index) {
              final account = stats.accounts[index];
              final balance = stats.accountBalances[account.id] ?? 0;
              return _buildAccountCard(context, account, balance, currency);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context, Account account, double balance, Currency currency) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: account.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconData(account.iconCodePoint, fontFamily: 'MaterialIcons'),
                  color: account.color,
                  size: 14,
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  account.name,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textLightColor(context)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            NumberFormat.currency(symbol: currency.symbol).format(balance),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, DashboardStats stats, Currency currency) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
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
                'Total Balance',
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
            NumberFormat.currency(symbol: currency.symbol).format(stats.currentBalance),
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

  Widget _buildIncomeExpenseRow(BuildContext context, DashboardStats stats, Currency currency) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: 'Income',
            amount: stats.totalIncome,
            gradient: AppTheme.successGradient,
            color: AppTheme.incomeColor(context),
            icon: Icons.arrow_downward_rounded,
            currency: currency,
          ),
        ),
        const Gap(12),
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: 'Expense',
            amount: stats.totalExpense,
            gradient: AppTheme.dangerGradient,
            color: AppTheme.expenseColor(context),
            icon: Icons.arrow_upward_rounded,
            currency: currency,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required double amount,
    required Color color,
    required LinearGradient gradient,
    required IconData icon,
    required Currency currency,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(2),
                Text(
                  NumberFormat.currency(symbol: currency.symbol).format(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    overflow: TextOverflow.ellipsis,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, DashboardStats stats, Currency currency) {
    if (stats.totalIncome == 0 && stats.totalExpense == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.dividerColor(context)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 44, color: AppTheme.textLightColor(context).withValues(alpha: 0.3)),
            const Gap(12),
            Text('No data for chart yet', style: TextStyle(color: AppTheme.textLightColor(context), fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        ),
      );
    }
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 6,
                    centerSpaceRadius: 50,
                    startDegreeOffset: -90,
                    sections: [
                      if (stats.totalIncome > 0)
                        PieChartSectionData(
                          color: AppTheme.secondaryColor(context),
                          value: stats.totalIncome,
                          title: '',
                          radius: 18,
                        ),
                      if (stats.totalExpense > 0)
                        PieChartSectionData(
                          color: AppTheme.errorColor(context),
                          value: stats.totalExpense,
                          title: '',
                          radius: 18,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total', style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 11, fontWeight: FontWeight.w500)),
                    const Gap(2),
                    Text(
                      NumberFormat.compactCurrency(symbol: currency.symbol).format(stats.totalIncome + stats.totalExpense),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(16),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(context, 'Income', AppTheme.incomeColor(context), '${((stats.totalIncome / (stats.totalIncome + stats.totalExpense)) * 100).toStringAsFixed(0)}%'),
                const Gap(16),
                _buildLegendItem(context, 'Expense', AppTheme.expenseColor(context), '${((stats.totalExpense / (stats.totalIncome + stats.totalExpense)) * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color, String percentage) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const Gap(8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 12, fontWeight: FontWeight.w500)),
              Text(percentage, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetSection(BuildContext context, WidgetRef ref, DashboardStats stats, Currency currency) {
    final categories = ref.watch(categoryProvider);
    final budgetedCategories = categories.where((c) => c.budget != null && c.budget! > 0).toList();



    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textColor(context), letterSpacing: -0.3),
            ),
            TextButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
                ref.read(navigationProvider.notifier).setIndex(3);
                ref.read(pageControllerProvider).animateToPage(
                  3,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Manage', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const Gap(12),
        if (budgetedCategories.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.dividerColor(context)),
            ),
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 40, color: AppTheme.textLightColor(context).withValues(alpha: 0.3)),
                const Gap(12),
                Text(
                  'No budgets set yet',
                  style: TextStyle(color: AppTheme.textLightColor(context), fontWeight: FontWeight.w600),
                ),
                const Gap(16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                    ref.read(navigationProvider.notifier).setIndex(3);
                    ref.read(pageControllerProvider).animateToPage(
                      3,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                    foregroundColor: AppTheme.primaryColor(context),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Set Monthly Budgets'),
                ),
              ],
            ),
          )
        else
          ...budgetedCategories.map((category) {
          final spent = stats.categorySpending[category.id] ?? 0;
          final budget = category.budget!;
          final progress = (spent / budget).clamp(0.0, 1.0);
          final percent = (spent / budget * 100).toStringAsFixed(0);
          final isOver = spent > budget;

          return Container(
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                        color: category.color,
                        size: 18,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Gap(2),
                            Text(
                              isOver
                                ? 'Exceeded by ${NumberFormat.currency(symbol: currency.symbol).format(spent - budget)}'
                                : '${NumberFormat.currency(symbol: currency.symbol).format(budget - spent)} remaining',
                              style: TextStyle(
                                color: isOver ? AppTheme.expenseColor(context) : AppTheme.textLightColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                      Text(
                        '$percent%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isOver ? AppTheme.expenseColor(context) : AppTheme.primaryColor(context),
                            fontSize: 15,
                          ),
                      ),
                  ],
                ),
                const Gap(14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
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
                      NumberFormat.currency(symbol: currency.symbol).format(spent),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'of ${NumberFormat.currency(symbol: currency.symbol).format(budget)}',
                      style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

      ],
    );
  }

  Widget _buildRecentTransactions(BuildContext context, AsyncValue transactionsAsync, Currency currency) {
    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.dividerColor(context)),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 44, color: AppTheme.textLightColor(context).withValues(alpha: 0.3)),
                const Gap(12),
                Text('No recent transactions', style: TextStyle(color: AppTheme.textLightColor(context), fontWeight: FontWeight.w500, fontSize: 14)),
              ],
            ),
          );
        }

        final recent = transactions.take(10).toList();
        return Column(
          children: recent.map<Widget>((tx) {
            final isIncome = tx.type == TransactionType.income;
            final isTransfer = tx.type == TransactionType.transfer;

            final color = isTransfer
                ? AppTheme.transferColor(context)
                : (isIncome ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context));

            final icon = isTransfer
                ? Icons.swap_horiz_rounded
                : (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.dividerColor(context)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    DateFormat.yMMMd().format(tx.date),
                    style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                trailing: Text(
                  isTransfer
                    ? NumberFormat.currency(symbol: currency.symbol).format(tx.amount)
                    : '${isIncome ? '+' : '-'}${NumberFormat.currency(symbol: currency.symbol).format(tx.amount)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
