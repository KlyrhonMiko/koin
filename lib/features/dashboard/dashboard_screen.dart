import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/utils/icon_utils.dart';
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
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/core/widgets/account_sheet.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.light_mode_rounded;
    if (hour < 17) return Icons.wb_sunny_rounded;
    return Icons.dark_mode_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final transactionsAsync = ref.watch(transactionProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () {
          HapticService.light();
          return ref.read(transactionProvider.notifier).loadTransactions();
        },
        color: AppTheme.primaryColor(context),
        backgroundColor: AppTheme.surfaceColor(context),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context)
                  .animate()
                  .fade(duration: 500.ms)
                  .slideY(begin: -0.1, duration: 500.ms, curve: Curves.easeOutCubic),
              const Gap(24),
              _buildBalanceCard(context, stats, currency)
                  .animate()
                  .fade(duration: 600.ms, delay: 100.ms)
                  .slideY(begin: 0.12, duration: 600.ms, delay: 100.ms, curve: Curves.easeOutCubic),
              const Gap(20),
              _buildAccountsList(context, ref, stats, currency)
                  .animate()
                  .fade(delay: 200.ms, duration: 500.ms)
                  .slideY(begin: 0.1, delay: 200.ms, duration: 500.ms, curve: Curves.easeOutCubic),
              const Gap(20),
              _buildIncomeExpenseRow(context, stats, currency)
                  .animate()
                  .fade(delay: 300.ms, duration: 500.ms)
                  .slideY(begin: 0.1, delay: 300.ms, duration: 500.ms, curve: Curves.easeOutCubic),
              const Gap(28),
              _buildBudgetSection(context, ref, stats, currency)
                  .animate()
                  .fade(delay: 400.ms, duration: 500.ms)
                  .slideY(begin: 0.1, delay: 400.ms, duration: 500.ms, curve: Curves.easeOutCubic),
              const Gap(28),
              _buildSectionHeader(
                context,
                ref,
                title: 'Spending Overview',
                buttonLabel: 'Full Analysis',
                onTap: () {
                  ref.read(navigationProvider.notifier).setIndex(1);
                  HapticService.light();
                  ref.read(pageControllerProvider).animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ).animate().fade(delay: 500.ms, duration: 500.ms),
              const Gap(16),
              _buildChartSection(context, stats, currency)
                  .animate()
                  .fade(delay: 550.ms, duration: 600.ms)
                  .scale(begin: const Offset(0.96, 0.96), delay: 550.ms, duration: 600.ms, curve: Curves.easeOutCubic),
              const Gap(28),
              _buildSectionHeader(
                context,
                ref,
                title: 'Recent Transactions',
                buttonLabel: 'View All',
                onTap: () {
                  ref.read(navigationProvider.notifier).setIndex(1);
                  HapticService.light();
                  ref.read(pageControllerProvider).animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ).animate().fade(delay: 600.ms, duration: 500.ms),
              const Gap(12),
              _buildRecentTransactions(context, ref, transactionsAsync, currency)
                  .animate()
                  .fade(delay: 650.ms, duration: 500.ms)
                  .slideY(begin: 0.08, delay: 650.ms, duration: 500.ms, curve: Curves.easeOutCubic),
              const Gap(100),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Consistent Section Header ────────────────────────────────────
  Widget _buildSectionHeader(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor(context),
            letterSpacing: -0.3,
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticService.light();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              buttonLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Header ───────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Gap(8),
                  Icon(
                    _getGreetingIcon(),
                    color: AppTheme.primaryColor(context),
                    size: 24,
                  ),
                ],
              ),
              const Gap(4),
              Text(
                dateStr,
                style: TextStyle(
                  color: AppTheme.textLightColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticService.light();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLightColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.dividerColor(context).withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.settings_outlined,
              color: AppTheme.textLightColor(context),
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Balance Card (Hero) ──────────────────────────────────────────
  Widget _buildBalanceCard(BuildContext context, DashboardStats stats, Currency currency) {
    final netChange = stats.totalIncome - stats.totalExpense;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient(context),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles overlay for depth
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      currency.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              Text(
                NumberFormat.currency(symbol: currency.symbol).format(stats.currentBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const Gap(16),
              // Net change chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: netChange >= 0
                      ? Colors.white.withValues(alpha: 0.18)
                      : (isDark ? Colors.red.withValues(alpha: 0.25) : Colors.red.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      netChange >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const Gap(6),
                    Text(
                      '${netChange >= 0 ? '+' : ''}${NumberFormat.compactCurrency(symbol: currency.symbol).format(netChange)} this period',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Accounts Grid ─────────────────────────────────────────────────
  Widget _buildAccountsList(BuildContext context, WidgetRef ref, DashboardStats stats, Currency currency) {
    if (stats.accounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accounts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor(context),
            letterSpacing: -0.3,
          ),
        ),
        const Gap(12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final cardWidth = (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                ...stats.accounts.map((account) {
                  final balance = stats.accountBalances[account.id] ?? 0;
                  return SizedBox(
                    width: cardWidth,
                    child: GestureDetector(
                      onTap: () => HapticService.light(),
                      child: _buildAccountCard(context, account, balance, currency),
                    ),
                  );
                }),
                if (stats.accounts.length % 2 != 0)
                  SizedBox(
                    width: cardWidth,
                    child: _buildAddAccountCard(context, ref),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context, Account account, double balance, Currency currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            account.color.withValues(alpha: 0.08),
            account.color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: account.color.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: account.color.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: account.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconUtils.getIcon(account.iconCodePoint),
                  color: account.color,
                  size: 14,
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  account.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textLightColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(12),
          Text(
            NumberFormat.currency(symbol: currency.symbol).format(balance),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountCard(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticService.medium();
        AccountSheet.show(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.primaryColor(context),
                size: 20,
              ),
            ),
            const Gap(10),
            Text(
              'Add Account',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.primaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Income / Expense Row ─────────────────────────────────────────
  Widget _buildIncomeExpenseRow(BuildContext context, DashboardStats stats, Currency currency) {

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticService.medium();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.income)),
              );
            },
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
        ),
        const Gap(12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticService.medium();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.expense)),
              );
            },
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.dividerColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
          const Gap(14),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textLightColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(4),
          Text(
            NumberFormat.currency(symbol: currency.symbol).format(amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              overflow: TextOverflow.ellipsis,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
          ),
          const Gap(12),
          // Colored accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Chart Section ────────────────────────────────────────────────
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
            Text(
              'No data for chart yet',
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 230,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.dividerColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          return;
                        }
                        if (event is FlTapDownEvent || event is FlPanStartEvent) {
                          HapticService.light();
                        }
                      },
                    ),
                    sectionsSpace: 5,
                    centerSpaceRadius: 48,
                    startDegreeOffset: -90,
                    sections: [
                      if (stats.totalIncome > 0)
                        PieChartSectionData(
                          color: AppTheme.secondaryColor(context),
                          value: stats.totalIncome,
                          title: '',
                          radius: 22,
                          borderSide: BorderSide(
                            color: AppTheme.secondaryColor(context).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      if (stats.totalExpense > 0)
                        PieChartSectionData(
                          color: AppTheme.errorColor(context),
                          value: stats.totalExpense,
                          title: '',
                          radius: 22,
                          borderSide: BorderSide(
                            color: AppTheme.errorColor(context).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Net',
                      style: TextStyle(
                        color: AppTheme.textLightColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(2),
                    Builder(
                      builder: (context) {
                        final net = stats.totalIncome - stats.totalExpense;
                        final formattedAmount = NumberFormat.compact().format(net.abs());
                        return Text(
                          '${net < 0 ? '−' : ''}${currency.symbol}$formattedAmount',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5, // Slightly smaller to avoid crowding
                            letterSpacing: -0.5,
                            color: net >= 0 
                                ? AppTheme.incomeColor(context) 
                                : AppTheme.expenseColor(context),
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(20),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  context,
                  'Income',
                  AppTheme.incomeColor(context),
                  NumberFormat.compactCurrency(symbol: currency.symbol).format(stats.totalIncome),
                ),
                const Gap(20),
                _buildLegendItem(
                  context,
                  'Expense',
                  AppTheme.expenseColor(context),
                  NumberFormat.compactCurrency(symbol: currency.symbol).format(stats.totalExpense),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color, String amount) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textLightColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Budget Section ───────────────────────────────────────────────
  Widget _buildBudgetSection(BuildContext context, WidgetRef ref, DashboardStats stats, Currency currency) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final budgetedCategories = categories.where((c) => c.type == TransactionType.expense && ((c.budget != null && c.budget! > 0) || (c.isPercentBudget && c.budgetPercent != null && c.budgetPercent! > 0))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          ref,
          title: 'Budget Progress',
          buttonLabel: 'Manage',
          onTap: () {
            Navigator.popUntil(context, (route) => route.isFirst);
            ref.read(navigationProvider.notifier).setIndex(3);
            ref.read(pageControllerProvider).animateToPage(
              3,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
        const Gap(14),
        if (budgetedCategories.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.dividerColor(context)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor(context).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 32,
                    color: AppTheme.primaryColor(context).withValues(alpha: 0.5),
                  ),
                ),
                const Gap(14),
                Text(
                  'No budgets set yet',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Gap(6),
                Text(
                  'Set monthly budgets to track spending',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const Gap(18),
                ElevatedButton(
                  onPressed: () {
                    HapticService.medium();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    ref.read(navigationProvider.notifier).setIndex(3);
                    ref.read(pageControllerProvider).animateToPage(
                      3,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor(context),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Set Monthly Budgets', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )
        else
          ...budgetedCategories.map((category) {
            final spent = stats.categorySpending[category.id] ?? 0;
            final budget = (category.isPercentBudget && category.budgetPercent != null && category.budgetPercent! > 0)
                ? stats.totalIncome * category.budgetPercent! / 100
                : (category.budget ?? 0.0);
            final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
            final percent = budget > 0 ? (spent / budget * 100).toStringAsFixed(0) : '0';
            final isOver = spent > budget;
            final isNearLimit = progress > 0.8 && !isOver;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isOver
                      ? AppTheme.errorColor(context).withValues(alpha: 0.3)
                      : AppTheme.dividerColor(context),
                ),
                boxShadow: [
                  if (isOver)
                    BoxShadow(
                      color: AppTheme.errorColor(context).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          IconUtils.getIcon(category.iconCodePoint),
                          color: category.color,
                          size: 18,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOver
                              ? AppTheme.expenseColor(context).withValues(alpha: 0.1)
                              : (isNearLimit
                                  ? Colors.amber.withValues(alpha: 0.1)
                                  : AppTheme.primaryColor(context).withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$percent%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isOver
                                ? AppTheme.expenseColor(context)
                                : (isNearLimit ? Colors.amber.shade700 : AppTheme.primaryColor(context)),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(14),
                  // Custom gradient progress bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isOver
                              ? AppTheme.dangerGradient
                              : LinearGradient(
                                  colors: [
                                    category.color.withValues(alpha: 0.7),
                                    category.color,
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            if (isNearLimit)
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                          ],
                        ),
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

  // ─── Recent Transactions ──────────────────────────────────────────
  Widget _buildRecentTransactions(BuildContext context, WidgetRef ref, AsyncValue transactionsAsync, Currency currency) {
    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.dividerColor(context)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor(context).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: AppTheme.primaryColor(context).withValues(alpha: 0.5),
                  ),
                ),
                const Gap(14),
                Text(
                  'No recent transactions',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Gap(4),
                Text(
                  'Tap + to add your first transaction',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        final recent = transactions.take(10).toList();
        final categories = ref.watch(categoriesProvider).value ?? [];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        // Group transactions by date label
        String getDateLabel(DateTime date) {
          final d = DateTime(date.year, date.month, date.day);
          if (d == today) return 'Today';
          if (d == yesterday) return 'Yesterday';
          final diff = today.difference(d).inDays;
          if (diff < 7) return 'This Week';
          return DateFormat.yMMMd().format(date);
        }

        final List<Widget> items = [];
        String? lastLabel;

        for (final tx in recent) {
          final label = getDateLabel(tx.date);
          if (label != lastLabel) {
            if (lastLabel != null) items.add(const Gap(8));
            items.add(
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            );
            lastLabel = label;
          }

          final isIncome = tx.type == TransactionType.income;
          final isTransfer = tx.type == TransactionType.transfer;

          final color = isTransfer
              ? AppTheme.transferColor(context)
              : (isIncome ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context));

          final category = categories.where((c) => c.id == tx.categoryId).firstOrNull;
          final categoryName = category?.name ?? 'Others';
          final displayTitle = tx.note.isEmpty ? categoryName : tx.note;

          // Use category icon if available, fallback to type-based icon
          final IconData txIcon;
          if (isTransfer) {
            txIcon = Icons.swap_horiz_rounded;
          } else if (category != null) {
            txIcon = IconUtils.getIcon(category.iconCodePoint);
          } else {
            txIcon = isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
          }

          final Color iconBgColor = isTransfer
              ? color.withValues(alpha: 0.12)
              : (category != null ? category.color.withValues(alpha: 0.12) : color.withValues(alpha: 0.12));
          final Color iconColor = isTransfer
              ? color
              : (category != null ? category.color : color);

          items.add(
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.dividerColor(context)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticService.light();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(txIcon, color: iconColor, size: 20),
                        ),
                        const Gap(14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const Gap(3),
                              Text(
                                isTransfer ? 'Transfer' : categoryName,
                                style: TextStyle(
                                  color: AppTheme.textLightColor(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
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
                            const Gap(2),
                            Text(
                              DateFormat.jm().format(tx.date),
                              style: TextStyle(
                                color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(children: items);
      },
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      ),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
