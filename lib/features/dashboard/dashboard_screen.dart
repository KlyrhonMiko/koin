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
import 'package:koin/core/providers/effective_transaction_clock_provider.dart';
import 'package:koin/core/widgets/cards/account_card_layout.dart';

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
    if (hour < 12) return KoinIcons.sun;
    if (hour < 17) return KoinIcons.sun;
    return KoinIcons.moon;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(calendarDayProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final transactionsAsync = ref.watch(transactionProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final automaticPayments = ref.watch(automaticPaymentsProvider);
    final accountsAsync = ref.watch(accountProvider);
    final now = ref.watch(effectiveTransactionClockProvider);
    if (!transactionsAsync.hasValue || !accountsAsync.hasValue) {
      final failed = transactionsAsync.hasError || accountsAsync.hasError;
      void retry() {
        ref.invalidate(transactionProvider);
        ref.invalidate(accountProvider);
      }

      return SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(transactionProvider.notifier).loadTransactions(),
              ref.read(accountProvider.notifier).loadAccounts(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              KoinSpacing.screenInset,
              16,
              KoinSpacing.screenInset,
              KoinSpacing.bottomClearance(context),
            ),
            children: [
              _buildHeader(context),
              const Gap(24),
              if (failed)
                KoinErrorState(
                  key: const ValueKey('dashboard_financial_error'),
                  message: 'Could not load your balances.',
                  onRetry: retry,
                )
              else
                Semantics(
                  liveRegion: true,
                  label: 'Loading balances',
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              const Gap(24),
              _buildQuickActions(context, ref),
            ],
          ),
        ),
      );
    }

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
          padding: EdgeInsets.fromLTRB(
            KoinSpacing.screenInset,
            16,
            KoinSpacing.screenInset,
            KoinSpacing.bottomClearance(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                [
                      _buildHeader(context),
                      if (automaticPayments.problems.isNotEmpty)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automatic payments need attention',
                                  style: TextStyle(
                                    color: AppTheme.errorColor(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Gap(8),
                                for (final problem
                                    in automaticPayments.problems)
                                  Text(problem),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        ref
                                            .read(portfolioTabProvider.notifier)
                                            .setIndex(3);
                                        ref
                                            .read(navigationProvider.notifier)
                                            .setIndex(3);
                                      },
                                      child: const Text('Review bills'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        ref
                                            .read(portfolioTabProvider.notifier)
                                            .setIndex(4);
                                        ref
                                            .read(navigationProvider.notifier)
                                            .setIndex(3);
                                      },
                                      child: const Text('Review incomes'),
                                    ),
                                    TextButton(
                                      onPressed: automaticPayments.busy
                                          ? null
                                          : () => ref
                                                .read(
                                                  automaticPaymentsProvider
                                                      .notifier,
                                                )
                                                .processDue(),
                                      child: Text(
                                        automaticPayments.busy
                                            ? 'Retrying…'
                                            : 'Retry',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Gap(12),
                      _buildBalanceCard(context, ref, stats, settings),
                      const Gap(12),
                      _buildQuickActions(context, ref),
                      if (stats.accounts.any(
                        (account) => !account.isArchived,
                      )) ...[
                        const Gap(12),
                        _buildAccountsList(context, ref, stats, currency),
                      ],
                      const Gap(12),
                      _buildUpcomingPayments(context, ref, currency),
                      const Gap(12),
                      _buildBudgetSection(context, ref, currency),
                      const Gap(12),
                      KoinSectionHeader(
                        title: 'Spending Overview',
                        actionLabel: 'Full Analysis',
                        onActionTap: () {
                          ref.read(activityTabProvider.notifier).setIndex(0);
                          ref.read(navigationProvider.notifier).setIndex(1);
                        },
                      ),
                      const Gap(4),
                      _buildChartSection(
                        context,
                        currency,
                        transactionsAsync.value ?? [],
                        now,
                      ),
                      const Gap(12),
                      KoinSectionHeader(
                        title: 'Recent Transactions',
                        actionLabel: 'View All',
                        onActionTap: () {
                          ref.read(activityTabProvider.notifier).setIndex(1);
                          ref.read(navigationProvider.notifier).setIndex(1);
                        },
                      ),
                      const Gap(4),
                      _buildRecentTransactions(
                        context,
                        ref,
                        transactionsAsync,
                        currency,
                        now,
                      ),
                    ]
                    .koinAnimate(
                      context,
                      autoPlay: !MediaQuery.disableAnimationsOf(context),
                      onInit: KoinMotion.onInit(context),
                      interval: KoinMotion.duration(context, 40.ms),
                    )
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
                  color: AppTheme.textLightColor(context)
                      .withValues(alpha: 0.7),
                  fontSize: KoinTypography.overline,
                  fontWeight: KoinTypography.titleWeight,
                  letterSpacing: KoinTypography.overlineTracking,
                ),
              ),
              const Gap(4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _getGreeting(),
                      style: TextStyle(
                        color: AppTheme.textColor(context),
                        fontSize: KoinTypography.screenTitle,
                        fontWeight: KoinTypography.headingWeight,
                        letterSpacing: KoinTypography.headingTracking,
                      ),
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
          icon: Icon(KoinIcons.gearSix, color: AppTheme.textColor(context)),
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
    final excludedSavings = ref.watch(dashboardExcludedSavingsProvider);
    final netChange = stats.totalIncome - stats.totalExpense;
    final monthlyAmount = currency.compactFormatter.format(netChange.abs());
    final monthlySummary = settings.hideBalance
        ? 'Monthly summary hidden'
        : netChange == 0
        ? 'Income matched spending this month'
        : netChange > 0
        ? 'Earned $monthlyAmount more than spent this month'
        : 'Spent $monthlyAmount more than earned this month';

    return KoinSummaryCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      borderRadius: KoinShape.summary,
      shapeStyle: SummaryShapeStyle.dashboard,
      topRightAction: KoinVisibilityButton(
        key: const ValueKey('dashboard_balance_visibility'),
        hidden: settings.hideBalance,
        subject: 'total balance',
        onPressed: () => ref
            .read(settingsProvider.notifier)
            .setHideBalance(!settings.hideBalance),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 44),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  excludedSavings > 0 ? 'Available Balance' : 'Total Balance',
                  style: KoinTypography.summaryLabelStyle,
                ),
                ExcludeSemantics(
                  child: Text(
                    '·',
                    style: KoinTypography.summaryLabelStyle.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Text(currency.code, style: KoinTypography.summaryLabelStyle),
              ],
            ),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: SizedBox(
              width: double.infinity,
              child: settings.hideBalance
                  ? const _HiddenBalanceMask(
                      color: Colors.white,
                      height:
                          KoinTypography.summaryAmount *
                          KoinTypography.amountHeight,
                      prominent: true,
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedCounter(
                        value: stats.currentBalance - excludedSavings,
                        lastValueToken: 'dashboard_total_balance',
                        formatter: currency.formatter.format,
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        style: KoinTypography.summaryAmountStyle,
                      ),
                    ),
            ),
          ),
          const Gap(12),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactWidth = constraints.maxWidth.clamp(0.0, 280.0);
        final actionWidth = (constraints.maxWidth + compactWidth) / 2;
        final actions = <Widget>[
          _buildActionItem(
            context,
            icon: KoinIcons.plus,
            label: 'Income',
            color: AppTheme.incomeContentColor(context),
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
            icon: KoinIcons.minus,
            label: 'Expense',
            color: AppTheme.expenseContentColor(context),
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
            icon: KoinIcons.arrowsLeftRight,
            label: 'Transfer',
            color: AppTheme.transferContentColor(context),
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
            icon: KoinIcons.calculator,
            label: 'Budgets',
            color: AppTheme.contentColor(
              context,
              AppTheme.primaryColor(context),
            ),
            onTap: () {
              HapticService.medium();
              Navigator.popUntil(context, (route) => route.isFirst);
              ref.read(navigationProvider.notifier).setIndex(2);
            },
          ),
        ];
        final stack =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(12) > 18;
        return Center(
          child: SizedBox(
            width: actionWidth,
            child: stack
                ? Column(
                    children: [
                      Row(children: actions.take(2).toList()),
                      const Gap(16),
                      Row(children: actions.skip(2).toList()),
                    ],
                  )
                : Row(children: actions),
          ),
        );
      },
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: KoinQuickAction(
        icon: icon,
        label: label,
        color: color,
        onPressed: onTap,
        size: 48,
        labelGap: 6,
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
    final activeAccounts = stats.accounts.where((a) => !a.isArchived).toList();
    if (activeAccounts.isEmpty) return const SizedBox.shrink();
    final displayedBalances = ref.watch(dashboardAccountBalancesProvider);
    final visibleAccounts = activeAccounts.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KoinSectionHeader(
          title: 'Accounts',
          actionLabel: 'View all · ${activeAccounts.length}',
          onActionTap: () {
            ref.read(portfolioTabProvider.notifier).setIndex(0);
            ref.read(navigationProvider.notifier).setIndex(3);
          },
        ),
        const Gap(8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = AccountCardLayout.columnsFor(
              context,
              constraints.maxWidth,
            );
            final cardWidth =
                (constraints.maxWidth - KoinSpacing.cardGap * (columns - 1)) /
                columns;
            return Wrap(
              spacing: KoinSpacing.cardGap,
              runSpacing: KoinSpacing.cardGap,
              children: [
                for (final account in visibleAccounts)
                  SizedBox(
                    width: cardWidth,
                    child: AccountItem(
                      compact: true,
                      account: account,
                      balance: displayedBalances[account.id] ?? 0,
                      currencySymbol: currency.symbol,
                      currency: currency,
                      onTap: () {
                        Navigator.push(
                          context,
                          SlideUpRoute(
                            page: AccountFormScreen(account: account),
                          ),
                        );
                      },
                      onPrivateToggle: () async {
                        try {
                          await ref
                              .read(accountProvider.notifier)
                              .updateAccount(
                                account.copyWith(
                                  excludeFromTotal: !account.excludeFromTotal,
                                ),
                              );
                          HapticService.selection();
                        } catch (_) {
                          if (context.mounted) {
                            KoinSnackBar.error(
                              context,
                              'Could not update account inclusion',
                              subtitle: 'Try again.',
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ─── Chart Section ────────────────────────────────────────────────
  Widget _buildChartSection(
    BuildContext context,
    Currency currency,
    List<AppTransaction> transactions,
    DateTime now,
  ) {
    final week = AnalysisPeriod.week.dateRange(now);
    final expenses = transactions
        .where(
          (tx) =>
              tx.countsAsExpense &&
              !tx.date.isAfter(now) &&
              !tx.date.isBefore(week.start) &&
              !tx.date.isAfter(week.end),
        )
        .toList();
    if (expenses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No spending this week',
          style: TextStyle(color: AppTheme.textLightColor(context)),
        ),
      );
    }

    return SpendingTrendChart(
      expenses: expenses,
      currency: currency,
      filterIndex: 0, // Weekly trend for dashboard
      baseDate: now,
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
        const Gap(4),
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
    DateTime now,
  ) {
    return transactionsAsync.when(
      data: (transactions) {
        final recent = transactions
            .where((tx) => !tx.date.isAfter(now))
            .take(10)
            .toList();
        if (recent.isEmpty) {
          return const KoinEmptyState(
            icon: KoinIcons.receipt,
            title: 'No recent transactions',
            subtitle: 'Tap + to add your first transaction',
          );
        }

        final categories = ref.watch(categoriesProvider).value ?? [];
        final accounts = ref.watch(accountProvider).value ?? [];
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final weekStart = AnalysisPeriod.week.dateRange(now).start;

        // Group transactions by date label
        String getDateLabel(DateTime date) {
          final d = DateTime(date.year, date.month, date.day);
          if (d == today) return 'Today';
          if (d == yesterday) return 'Yesterday';
          if (!d.isBefore(weekStart)) return 'This Week';
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
                    color: AppTheme.textLightColor(context)
                        .withValues(alpha: 0.6),
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
                    color: AppTheme.dividerColor(context)
                        .withValues(alpha: 0.5),
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
      error: (_, _) =>
          KoinErrorState(onRetry: () => ref.invalidate(transactionProvider)),
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
        const Gap(4),
        timeline.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => KoinErrorState(
            message: 'Could not load upcoming entries.',
            onRetry: () => retryUpcoming(ref),
          ),
          data: (timeline) => timeline.isEmpty
              ? _buildEmptyUpcoming(context, ref)
              : Column(
                  spacing: 8,
                  children: timeline.take(3).map((entry) {
                    final category = categories
                        .where((c) => c.id == entry.categoryId)
                        .firstOrNull;

                    final child = UpcomingEntryTile(
                      key: ValueKey(entry.id),
                      entry: entry,
                      currency: currency,
                      margin: EdgeInsets.zero,
                      category: category,
                      onPayPayment: (payment) =>
                          PaymentConfirmationSheet.confirmAndProcess(
                            context: context,
                            ref: ref,
                            payment: payment,
                          ),
                    );

                    return child;
                  }).toList(),
                ),
        ),
      ],
    );

    return content;
  }

  Widget _buildEmptyUpcoming(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nothing upcoming',
          style: TextStyle(
            fontSize: KoinTypography.itemTitle,
            color: AppTheme.textColor(context),
          ),
        ),
        const Gap(4),
        Text(
          'Add a planned payment or recurring income to see it here',
          style: TextStyle(
            fontSize: KoinTypography.caption,
            color: AppTheme.textLightColor(context),
          ),
        ),
        const Gap(8),
        TextButton.icon(
          onPressed: () {
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
          icon: const Icon(KoinIcons.plus),
          label: const Text('Add planned payment'),
        ),
      ],
    ),
  );
}

class _HiddenBalanceMask extends StatelessWidget {
  const _HiddenBalanceMask({
    required this.color,
    required this.height,
    this.prominent = false,
  });

  final Color color;
  final double height;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '****',
          semanticsLabel: 'Balance hidden',
          style: TextStyle(
            fontFamily: KoinTypography.fontFamily,
            color: color.withValues(alpha: 0.85),
            fontSize: prominent ? 30 : KoinTypography.sectionTitle,
            fontWeight: KoinTypography.supportingWeight,
            letterSpacing: prominent ? 1.5 : 1,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}
