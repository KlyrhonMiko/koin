import 'package:flutter/material.dart';
import 'package:koin/core/utils/slide_up_route.dart';
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
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/widgets/animated_counter.dart';

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
                  .slideY(
                    begin: -0.1,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const Gap(24),
              _buildBalanceCard(context, stats, currency)
                  .animate()
                  .fade(duration: 600.ms, delay: 100.ms)
                  .slideY(
                    begin: 0.12,
                    duration: 600.ms,
                    delay: 100.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const Gap(24),
              _buildQuickActions(context, ref)
                  .animate()
                  .fade(delay: 200.ms, duration: 500.ms)
                  .slideY(
                    begin: 0.1,
                    delay: 200.ms,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const Gap(28),
              _buildAccountsList(context, ref, stats, currency)
                  .animate()
                  .fade(delay: 300.ms, duration: 500.ms)
                  .slideY(
                    begin: 0.1,
                    delay: 300.ms,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const Gap(28),
              _buildBudgetSection(context, ref, stats, currency)
                  .animate()
                  .fade(delay: 400.ms, duration: 500.ms)
                  .slideY(
                    begin: 0.1,
                    delay: 400.ms,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const Gap(32),
              _buildSectionHeader(
                context,
                ref,
                title: 'Spending Overview',
                buttonLabel: 'Full Analysis',
                onTap: () {
                  ref.read(navigationProvider.notifier).setIndex(1);
                  HapticService.light();
                  ref
                      .read(pageControllerProvider)
                      .animateToPage(
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
                  .scale(
                    begin: const Offset(0.96, 0.96),
                    delay: 550.ms,
                    duration: 600.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const Gap(28),
              _buildSectionHeader(
                context,
                ref,
                title: 'Recent Transactions',
                buttonLabel: 'View All',
                onTap: () {
                  ref.read(navigationProvider.notifier).setIndex(1);
                  HapticService.light();
                  ref
                      .read(pageControllerProvider)
                      .animateToPage(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                },
              ).animate().fade(delay: 600.ms, duration: 500.ms),
              const Gap(12),
              _buildRecentTransactions(
                    context,
                    ref,
                    transactionsAsync,
                    currency,
                  )
                  .animate()
                  .fade(delay: 650.ms, duration: 500.ms)
                  .slideY(
                    begin: 0.08,
                    delay: 650.ms,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
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
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.textColor(context),
            letterSpacing: -0.4,
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticService.light();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textLightColor(context),
                  ),
                ),
                const Gap(4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: AppTheme.textLightColor(context),
                ),
              ],
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
              Text(
                dateStr.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Gap(4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Gap(8),
                  Icon(
                    _getGreetingIcon(),
                    color: AppTheme.primaryColor(context),
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticService.light();
            Navigator.push(context, SlideUpRoute(page: const SettingsScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.settings_outlined,
              color: AppTheme.textColor(context),
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Balance Card (Hero) ──────────────────────────────────────────
  Widget _buildBalanceCard(
    BuildContext context,
    DashboardStats stats,
    Currency currency,
  ) {
    final netChange = stats.totalIncome - stats.totalExpense;

    return Container(
      padding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circles overlay for depth
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
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
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currency.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              AnimatedCounter(
                value: stats.currentBalance,
                formatter: (v) =>
                    NumberFormat.currency(symbol: currency.symbol).format(v),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const Gap(20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Net change chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          netChange >= 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const Gap(4),
                        AnimatedCounter(
                          value: netChange.abs(),
                          formatter: (v) =>
                              '${NumberFormat.compactCurrency(symbol: currency.symbol).format(v)} this month',
                          duration: const Duration(milliseconds: 1200),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Small visual indicator of card type or app icon
                  Icon(
                    Icons.contactless_outlined,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick Actions ──────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionItem(
          context,
          icon: Icons.add_rounded,
          label: 'Income',
          color: AppTheme.incomeColor(context),
          onTap: () {
            HapticService.medium();
            Navigator.push(
              context,
              SlideUpRoute(
                page: const AddTransactionScreen(
                  initialType: TransactionType.income,
                ),
              ),
            );
          },
        ),
        _buildActionItem(
          context,
          icon: Icons.remove_rounded,
          label: 'Expense',
          color: AppTheme.expenseColor(context),
          onTap: () {
            HapticService.medium();
            Navigator.push(
              context,
              SlideUpRoute(
                page: const AddTransactionScreen(
                  initialType: TransactionType.expense,
                ),
              ),
            );
          },
        ),
        _buildActionItem(
          context,
          icon: Icons.swap_horiz_rounded,
          label: 'Transfer',
          color: AppTheme.transferColor(context),
          onTap: () {
            HapticService.medium();
            Navigator.push(
              context,
              SlideUpRoute(
                page: const AddTransactionScreen(
                  initialType: TransactionType.transfer,
                ),
              ),
            );
          },
        ),
        _buildActionItem(
          context,
          icon: Icons.savings_outlined,
          label: 'Budgets',
          color: AppTheme.primaryColor(context),
          onTap: () {
            HapticService.medium();
            Navigator.popUntil(context, (route) => route.isFirst);
            ref.read(navigationProvider.notifier).setIndex(3);
            ref
                .read(pageControllerProvider)
                .animateToPage(
                  3,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
          },
        ),
      ],
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      enableHaptic: false,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Gap(8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textLightColor(context),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Accounts List ─────────────────────────────────────────────────
  Widget _buildAccountsList(
    BuildContext context,
    WidgetRef ref,
    DashboardStats stats,
    Currency currency,
  ) {
    if (stats.accounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          ref,
          title: 'Accounts',
          buttonLabel: 'Add',
          onTap: () {
            AccountSheet.show(context, ref);
          },
        ),
        const Gap(4),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: stats.accounts.length + 1,
            separatorBuilder: (context, index) => const Gap(12),
            itemBuilder: (context, index) {
              if (index == stats.accounts.length) {
                return _buildAddAccountCard(context, ref);
              }
              final account = stats.accounts[index];
              final balance = stats.accountBalances[account.id] ?? 0;
              return GestureDetector(
                onTap: () => HapticService.light(),
                child: _buildAccountCard(context, account, balance, currency),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    Account account,
    double balance,
    Currency currency,
  ) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: account.color.withValues(alpha: 0.1),
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
          const Spacer(),
          AnimatedCounter(
            value: balance,
            formatter: (v) =>
                NumberFormat.currency(symbol: currency.symbol).format(v),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        width: 100,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: AppTheme.textLightColor(context),
              size: 22,
            ),
            const Gap(4),
            Text(
              'Add',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppTheme.textLightColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chart Section ────────────────────────────────────────────────
  Widget _buildChartSection(
    BuildContext context,
    DashboardStats stats,
    Currency currency,
  ) {
    if (stats.totalIncome == 0 && stats.totalExpense == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 44,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 16),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, radius, _) {
                    return PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  return;
                                }
                                if (event is FlTapDownEvent ||
                                    event is FlPanStartEvent) {
                                  HapticService.light();
                                }
                              },
                        ),
                        sectionsSpace: 4,
                        centerSpaceRadius: 65,
                        startDegreeOffset: -90,
                        sections: [
                          if (stats.totalIncome > 0)
                            PieChartSectionData(
                              color: AppTheme.secondaryColor(context),
                              value: stats.totalIncome,
                              title: '',
                              radius: radius,
                            ),
                          if (stats.totalExpense > 0)
                            PieChartSectionData(
                              color: AppTheme.errorColor(context),
                              value: stats.totalExpense,
                              title: '',
                              radius: radius,
                            ),
                        ],
                      ),
                    );
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Net',
                      style: TextStyle(
                        color: AppTheme.textLightColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(2),
                    Builder(
                      builder: (context) {
                        final net = stats.totalIncome - stats.totalExpense;
                        final formattedAmount = NumberFormat.compact().format(
                          net.abs(),
                        );
                        return Text(
                          '${net < 0 ? '−' : ''}${currency.symbol}$formattedAmount',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -0.5,
                            color: net >= 0
                                ? AppTheme.incomeColor(context)
                                : AppTheme.expenseColor(context),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                context,
                'Income',
                AppTheme.incomeColor(context),
                NumberFormat.compactCurrency(
                  symbol: currency.symbol,
                ).format(stats.totalIncome),
              ),
              Container(
                width: 1,
                height: 24,
                color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
              ),
              _buildLegendItem(
                context,
                'Expense',
                AppTheme.expenseColor(context),
                NumberFormat.compactCurrency(
                  symbol: currency.symbol,
                ).format(stats.totalExpense),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    Color color,
    String amount,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const Gap(8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                color: AppTheme.textColor(context),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Budget Section ───────────────────────────────────────────────
  Widget _buildBudgetSection(
    BuildContext context,
    WidgetRef ref,
    DashboardStats stats,
    Currency currency,
  ) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final budgetedCategories = categories
        .where(
          (c) =>
              c.type == TransactionType.expense &&
              ((c.budget != null && c.budget! > 0) ||
                  (c.isPercentBudget &&
                      c.budgetPercent != null &&
                      c.budgetPercent! > 0)),
        )
        .toList();

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
            ref
                .read(pageControllerProvider)
                .animateToPage(
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
                    color: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 32,
                    color: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.5),
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
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const Gap(18),
                ElevatedButton(
                  onPressed: () {
                    HapticService.medium();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    ref.read(navigationProvider.notifier).setIndex(3);
                    ref
                        .read(pageControllerProvider)
                        .animateToPage(
                          3,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor(context),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Set Monthly Budgets',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: budgetedCategories.length,
              separatorBuilder: (context, index) => const Gap(16),
              itemBuilder: (context, index) {
                final category = budgetedCategories[index];
                final spent = stats.categorySpending[category.id] ?? 0;
                final budget =
                    (category.isPercentBudget &&
                        category.budgetPercent != null &&
                        category.budgetPercent! > 0)
                    ? stats.totalIncome * category.budgetPercent! / 100
                    : (category.budget ?? 0.0);
                final progress = budget > 0
                    ? (spent / budget).clamp(0.0, 1.0)
                    : 0.0;
                final percent = budget > 0
                    ? (spent / budget * 100).toStringAsFixed(0)
                    : '0';
                final isOver = spent > budget;
                final isNearLimit = progress > 0.8 && !isOver;

                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isOver
                          ? AppTheme.errorColor(context).withValues(alpha: 0.3)
                          : AppTheme.dividerColor(
                              context,
                            ).withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              IconUtils.getIcon(category.iconCodePoint),
                              color: category.color,
                              size: 16,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isOver
                                  ? AppTheme.expenseColor(context)
                                  : (isNearLimit
                                        ? Colors.amber.shade700
                                        : AppTheme.primaryColor(context)),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        isOver
                            ? 'Exceeded by ${NumberFormat.compactCurrency(symbol: currency.symbol).format(spent - budget)}'
                            : '${NumberFormat.compactCurrency(symbol: currency.symbol).format(budget - spent)} left',
                        style: TextStyle(
                          color: isOver
                              ? AppTheme.expenseColor(context)
                              : AppTheme.textLightColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(10),
                      // Custom gradient progress bar
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, animValue, child) {
                          return Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.dividerColor(context),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: animValue,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: isOver
                                      ? AppTheme.dangerGradient
                                      : LinearGradient(
                                          colors: [
                                            category.color.withValues(
                                              alpha: 0.7,
                                            ),
                                            category.color,
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ─── Recent Transactions ──────────────────────────────────────────
  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    AsyncValue transactionsAsync,
    Currency currency,
  ) {
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
                    color: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.5),
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
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
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

        for (int i = 0; i < recent.length; i++) {
          final tx = recent[i];
          final label = getDateLabel(tx.date);

          if (label != lastLabel) {
            if (lastLabel != null) items.add(const Gap(4));
            items.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
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
              : (isIncome
                    ? AppTheme.incomeColor(context)
                    : AppTheme.expenseColor(context));

          final category = categories
              .where((c) => c.id == tx.categoryId)
              .firstOrNull;
          final categoryName = category?.name ?? 'Others';
          final displayTitle = tx.note.isEmpty ? categoryName : tx.note;

          // Use category icon if available, fallback to type-based icon
          final IconData txIcon;
          if (isTransfer) {
            txIcon = Icons.swap_horiz_rounded;
          } else if (category != null) {
            txIcon = IconUtils.getIcon(category.iconCodePoint);
          } else {
            txIcon = isIncome
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded;
          }

          final Color iconBgColor = isTransfer
              ? color.withValues(alpha: 0.1)
              : (category != null
                    ? category.color.withValues(alpha: 0.1)
                    : color.withValues(alpha: 0.1));
          final Color iconColor = isTransfer
              ? color
              : (category != null ? category.color : color);

          items.add(
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticService.light();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
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
                                ? NumberFormat.currency(
                                    symbol: currency.symbol,
                                  ).format(tx.amount)
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
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.6),
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
          );

          // Add divider if not the last item AND the next item is of the same date
          if (i < recent.length - 1) {
            final nextLabel = getDateLabel(recent[i + 1].date);
            if (nextLabel == label) {
              items.add(
                Padding(
                  padding: const EdgeInsets.only(left: 64, right: 20),
                  child: Container(
                    height: 1,
                    color: AppTheme.dividerColor(
                      context,
                    ).withValues(alpha: 0.5),
                  ),
                ),
              );
            }
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
