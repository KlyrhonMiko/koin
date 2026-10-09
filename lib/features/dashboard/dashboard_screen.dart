import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/accounts.dart';
import 'package:koin/features/cashflow/cashflow.dart';
import 'package:koin/features/dashboard/upcoming_screen.dart';
import 'package:koin/features/dashboard/widgets/budget_progress_card.dart';
import 'package:koin/features/dashboard/widgets/upcoming_entry_tile.dart';
import 'package:koin/features/settings/settings_screen.dart';
import 'package:koin/features/transactions/transactions.dart';

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
          padding: const EdgeInsets.fromLTRB(
            KoinSpacing.screenInset,
            16,
            KoinSpacing.screenInset,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                [
                      _buildHeader(context),
                      const Gap(24),
                      _buildBalanceCard(context, ref, stats, settings),
                      const Gap(24),
                      _buildQuickActions(context, ref),
                      const Gap(KoinSpacing.sectionGap),
                      _buildAccountsList(context, ref, stats, currency),
                      const Gap(KoinSpacing.sectionGap),
                      _buildUpcomingPayments(context, ref, currency),
                      const Gap(KoinSpacing.sectionGap),
                      _buildBudgetSection(context, ref, currency),
                      const Gap(32),
                      KoinSectionHeader(
                        title: 'Spending Overview',
                        actionLabel: 'Full Analysis',
                        onActionTap: () {
                          ref.read(activityTabProvider.notifier).setIndex(0);
                          ref.read(navigationProvider.notifier).setIndex(1);
                        },
                      ),
                      const Gap(16),
                      _buildChartSection(
                        context,
                        stats,
                        currency,
                        transactionsAsync.value ?? [],
                      ),
                      const Gap(32),
                      KoinSectionHeader(
                        title: 'Recent Transactions',
                        actionLabel: 'View All',
                        onActionTap: () {
                          ref.read(activityTabProvider.notifier).setIndex(1);
                          ref.read(navigationProvider.notifier).setIndex(1);
                        },
                      ),
                      const Gap(12),
                      _buildRecentTransactions(
                        context,
                        ref,
                        transactionsAsync,
                        currency,
                      ),
                      const Gap(100),
                    ]
                    .animate(interval: 40.ms)
                    .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      duration: 250.ms,
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ),
      ),
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
                  fontSize: KoinTypography.overline,
                  fontWeight: KoinTypography.titleWeight,
                  letterSpacing: KoinTypography.overlineTracking,
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
                      fontSize: KoinTypography.screenTitle,
                      fontWeight: KoinTypography.headingWeight,
                      letterSpacing: KoinTypography.headingTracking,
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
        IconButton(
          onPressed: () {
            HapticService.light();
            Navigator.push(context, SlideUpRoute(page: const SettingsScreen()));
          },
          icon: Icon(
            Icons.settings_outlined,
            color: AppTheme.textColor(context),
          ),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  // ─── Balance Card (Hero) ──────────────────────────────────────────
  Widget _buildBalanceCard(
    BuildContext context,
    WidgetRef ref,
    DashboardStats stats,
    SettingsState settings,
  ) {
    final currency = settings.currency;
    final netChange = stats.totalIncome - stats.totalExpense;
    final monthlyAmount = NumberFormat.compactCurrency(
      symbol: currency.symbol,
    ).format(netChange.abs());
    final monthlySummary = settings.hideBalance
        ? 'This month: ••••••'
        : netChange == 0
        ? 'Income matched spending this month'
        : netChange > 0
        ? 'Earned $monthlyAmount more than spent this month'
        : 'Spent $monthlyAmount more than earned this month';

    return KoinSummaryCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      shapeStyle: SummaryShapeStyle.dashboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: KoinTypography.caption,
                  fontWeight: KoinTypography.labelWeight,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticService.selection();
                      ref
                          .read(settingsProvider.notifier)
                          .setHideBalance(!settings.hideBalance);
                    },
                    child: Icon(
                      settings.hideBalance
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white.withValues(
                        alpha: settings.hideBalance ? 0.6 : 0.9,
                      ),
                      size: 20,
                    ),
                  ),
                  const Gap(12),
                  Text(
                    currency.code,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: KoinTypography.labelWeight,
                      fontSize: KoinTypography.caption,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(16),
          settings.hideBalance
              ? const Text(
                  '••••••',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: KoinTypography.summaryAmount,
                    fontWeight: KoinTypography.headingWeight,
                    letterSpacing: 2.0,
                    height: KoinTypography.amountHeight,
                  ),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedCounter(
                    value: stats.currentBalance,
                    lastValueToken: 'dashboard_total_balance',
                    formatter: (v) => NumberFormat.currency(
                      symbol: currency.symbol,
                    ).format(v),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: KoinTypography.summaryAmount,
                      fontWeight: KoinTypography.headingWeight,
                      letterSpacing: KoinTypography.amountTracking,
                      height: KoinTypography.amountHeight,
                    ),
                  ),
                ),
          const Gap(16),
          Text(
            monthlySummary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: KoinTypography.labelWeight,
              fontSize: KoinTypography.small,
            ),
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
            ref.read(navigationProvider.notifier).setIndex(2);
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
                AppTheme.boxShadow(
                  context,
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
              fontSize: KoinTypography.small,
              fontWeight: KoinTypography.labelWeight,
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
        KoinSectionHeader(
          title: 'Accounts',
          actionLabel: 'View all',
          onActionTap: () {
            ref.read(portfolioTabProvider.notifier).setIndex(0);
            ref.read(navigationProvider.notifier).setIndex(3);
          },
        ),
        const Gap(4),
        LayoutBuilder(
          builder: (context, constraints) {
            // Keep a compact card width; adapt down on smaller screens.
            // The trailing partial card remains a cue to swipe.
            final cardWidth =
                ((constraints.maxWidth +
                            KoinSpacing.screenInset -
                            KoinSpacing.cardGap) /
                        1.8)
                    .clamp(0.0, 180.0);
            return SizedBox(
              // Keep the familiar credit-card silhouette as width changes.
              height: cardWidth / 1.586,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: stats.accounts.length + 1,
                separatorBuilder: (context, index) =>
                    const Gap(KoinSpacing.cardGap),
                itemBuilder: (context, index) {
                  if (index == stats.accounts.length) {
                    return _buildAddAccountCard(context, ref);
                  }
                  final account = stats.accounts[index];
                  final balance = stats.accountBalances[account.id] ?? 0;
                  return PressableScale(
                    onTap: () {
                      HapticService.light();
                      Navigator.push(
                        context,
                        SlideUpRoute(page: AccountFormScreen(account: account)),
                      );
                    },
                    child: _buildAccountCard(
                      context,
                      account,
                      balance,
                      currency,
                      width: cardWidth,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    Account account,
    double balance,
    Currency currency, {
    required double width,
  }) {
    final isColored = account.cardColor != null || account.logoAsset != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    BoxDecoration decoration;
    if (isColored) {
      final baseColor = account.cardColor ?? account.color;
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor.withValues(alpha: 0.95), baseColor],
        ),
        boxShadow: isDark
            ? null
            : [
                AppTheme.boxShadow(
                  context,
                  color: baseColor.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      );
    } else {
      decoration = BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppTheme.dividerColor(context).withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          AppTheme.boxShadow(
            context,
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    // Selected or Hash based shapes for variety (Synchronized with AccountItem)
    final shapeType = account.cardShapeType ?? (account.id.hashCode.abs() % 8);
    List<Widget> backgroundShapes = [];
    if (isColored) {
      switch (shapeType) {
        case 0:
          backgroundShapes = [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          ];
          break;
        case 1:
          backgroundShapes = [
            Positioned(
              right: -30,
              bottom: -40,
              child: Transform.rotate(
                angle: 0.4,
                child: Container(
                  width: 110,
                  height: 92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
          ];
          break;
        case 2:
          backgroundShapes = [
            Positioned(
              right: 30,
              top: -10,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: -15,
              bottom: -15,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          ];
          break;
        case 3:
        default:
          backgroundShapes = [
            Positioned(
              left: -30,
              bottom: -35,
              child: Transform.rotate(
                angle: 0.8,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -10,
              top: 10,
              child: Container(
                width: 50,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
          ];
          break;
      }
    }

    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: decoration,
      child: Stack(
        children: [
          ...backgroundShapes,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: account.logoAsset == null
                            ? (isColored
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : account.color.withValues(alpha: 0.12))
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: account.logoAsset != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                account.logoAsset!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Icon(
                                IconUtils.getIcon(account.iconCodePoint),
                                color: isColored ? Colors.white : account.color,
                                size: 18,
                              ),
                            ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        account.name,
                        style: TextStyle(
                          fontWeight: KoinTypography.labelWeight,
                          fontSize: KoinTypography.caption,
                          color: isColored
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppTheme.textColor(context),
                          letterSpacing: KoinTypography.itemTracking,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                account.excludeFromTotal
                    ? Text(
                        '••••••',
                        style: TextStyle(
                          color: isColored
                              ? Colors.white
                              : AppTheme.textColor(context),
                          fontWeight: KoinTypography.titleWeight,
                          fontSize: KoinTypography.cardAmount,
                          letterSpacing: 2,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedCounter(
                          value: balance,
                          lastValueToken: 'account_card_${account.id}',
                          formatter: (v) => NumberFormat.currency(
                            symbol: currency.symbol,
                          ).format(v),
                          style: TextStyle(
                            fontWeight: KoinTypography.titleWeight,
                            fontSize: KoinTypography.cardAmount,
                            letterSpacing: KoinTypography.itemTracking,
                            color: isColored
                                ? Colors.white
                                : AppTheme.textColor(context),
                          ),
                        ),
                      ),
              ],
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
        Navigator.push(context, SlideUpRoute(page: const AccountFormScreen()));
      },
      child: Container(
        width: 88,
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
                fontWeight: KoinTypography.labelWeight,
                fontSize: KoinTypography.small,
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
    List<AppTransaction> transactions,
  ) {
    if (stats.totalIncome == 0 && stats.totalExpense == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            AppTheme.boxShadow(
              context,
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
                fontWeight: KoinTypography.supportingWeight,
                fontSize: KoinTypography.compact,
              ),
            ),
          ],
        ),
      );
    }

    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    return SpendingTrendChart(
      expenses: expenses,
      currency: currency,
      filterIndex: 0, // Weekly trend for dashboard
    );
  }

  // ─── Budget Section ───────────────────────────────────────────────
  Widget _buildBudgetSection(
    BuildContext context,
    WidgetRef ref,
    Currency currency,
  ) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final overview = ref.watch(monthlyBudgetOverviewProvider(month));
    void manageBudgets() {
      HapticService.light();
      Navigator.popUntil(context, (route) => route.isFirst);
      ref.read(navigationProvider.notifier).setIndex(2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KoinSectionHeader(
          title: 'Budget Progress',
          actionLabel: 'Manage',
          onActionTap: manageBudgets,
        ),
        const Gap(14),
        BudgetProgressCard(
          overview: overview,
          currency: currency,
          onManage: manageBudgets,
        ),
      ],
    );
  }

  // ─── Recent Transactions ──────────────────────────────────────────
  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<AppTransaction>> transactionsAsync,
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
                    fontWeight: KoinTypography.labelWeight,
                    fontSize: KoinTypography.body,
                  ),
                ),
                const Gap(4),
                Text(
                  'Tap + to add your first transaction',
                  style: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
                    fontSize: KoinTypography.caption,
                  ),
                ),
              ],
            ),
          );
        }

        final recent = transactions.take(10).toList();
        final categories = ref.watch(categoriesProvider).value ?? [];
        final accounts = ref.watch(accountProvider).value ?? [];
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
                padding: const EdgeInsets.fromLTRB(
                  KoinSpacing.screenInset,
                  16,
                  KoinSpacing.screenInset,
                  8,
                ),
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
                    fontSize: KoinTypography.overline,
                    fontWeight: KoinTypography.titleWeight,
                    letterSpacing: KoinTypography.overlineTracking,
                  ),
                ),
              ),
            );
            lastLabel = label;
          }

          items.add(
            TransactionTile.resolve(
              transaction: tx,
              categories: categories,
              accounts: accounts,
              currency: currency,
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
              AppTheme.boxShadow(
                context,
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

  // ─── Upcoming Payments ───────────────────────────────────────────
  Widget _buildUpcomingPayments(
    BuildContext context,
    WidgetRef ref,
    Currency currency,
  ) {
    final timeline = ref.watch(upcomingTimelineProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KoinSectionHeader(
          title: 'Upcoming',
          actionLabel: 'View All',
          onActionTap: () {
            Navigator.push(context, SlideUpRoute(page: const UpcomingScreen()));
          },
        ),
        const Gap(16),
        if (timeline.isEmpty)
          _buildEmptyUpcoming(context, ref)
        else
          Column(
            children: timeline.take(3).map((entry) {
              final category = categories
                  .where((c) => c.id == entry.categoryId)
                  .firstOrNull;

              final trackId = 'dash_entry_${entry.id}';
              Widget child = UpcomingEntryTile(
                entry: entry,
                currency: currency,
                category: category,
                onPayPayment: (payment) =>
                    PaymentConfirmationSheet.confirmAndProcess(
                      context: context,
                      ref: ref,
                      payment: payment,
                    ),
              );

              if (!AnimationTracker.hasSeen(trackId)) {
                child = child.animate().fadeIn().slideY(begin: 0.1);
              }

              return child;
            }).toList(),
          ),
      ],
    );

    if (!AnimationTracker.hasSeen('dash_upcoming_section')) {
      content = content
          .animate()
          .fade(delay: 550.ms, duration: 500.ms)
          .slideY(
            begin: 0.1,
            delay: 550.ms,
            duration: 500.ms,
            curve: Curves.easeOutCubic,
          );
    }

    return content;
  }

  Widget _buildEmptyUpcoming(BuildContext context, WidgetRef ref) {
    return PressableScale(
      onTap: () {
        HapticService.medium();
        Navigator.push(
          context,
          SlideUpRoute(
            page: const AddEditCashflowScreen(
              initialType: TransactionType.expense,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_repeat_rounded,
              size: 32,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
            ),
            const Gap(12),
            Text(
              'No upcoming payments',
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontWeight: KoinTypography.labelWeight,
                fontSize: KoinTypography.compact,
              ),
            ),
            const Gap(4),
            Text(
              'Tap to add your first subscription',
              style: TextStyle(
                color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
                fontSize: KoinTypography.small,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
