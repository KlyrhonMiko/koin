import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/widgets/savings_log_sheet.dart';
import 'widgets/savings_routine_card.dart';

class SavingsDetailsScreen extends ConsumerStatefulWidget {
  final SavingsGoal goal;

  const SavingsDetailsScreen({super.key, required this.goal});

  @override
  ConsumerState<SavingsDetailsScreen> createState() =>
      _SavingsDetailsScreenState();
}

class _SavingsDetailsScreenState extends ConsumerState<SavingsDetailsScreen> {
  final Set<String> _expandedReleaseExplanations = {};

  Future<void> _saveLog({
    required SavingsGoal goal,
    SavingsLog? existingLog,
    required double amount,
  }) async {
    if (existingLog != null) {
      final newLog = SavingsLog(
        id: existingLog.id,
        goalId: existingLog.goalId,
        amount: amount,
        date: existingLog.date,
        note: existingLog.note,
        transactionId: existingLog.transactionId,
      );
      await ref
          .read(savingsGoalsProvider.notifier)
          .updateLog(existingLog, newLog);
      HapticService.success();
    } else {
      final log = SavingsLog(
        id: const Uuid().v4(),
        goalId: goal.id,
        amount: amount,
        date: DateTime.now(),
        note: amount < 0 ? 'Released for spending' : null,
      );

      final wasCompleted = goal.isCompleted;
      await ref.read(savingsGoalsProvider.notifier).addLog(log);
      final isNowCompleted = goal.willComplete(amount);

      if (!wasCompleted && isNowCompleted) {
        HapticService.success();
        await Future.delayed(const Duration(milliseconds: 150));
        HapticService.medium();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticService.heavy();
      } else {
        HapticService.success();
      }
    }
  }

  void _showAddLogSheet({
    required SavingsGoal goal,
    SavingsLog? log,
    bool release = false,
    Account? linkedAccount,
    double? linkedBalance,
  }) {
    SavingsLogSheet.show(
      context: context,
      goal: goal,
      log: log,
      release: release,
      linkedAccount: linkedAccount,
      linkedBalance: linkedBalance,
      onSave: (amount) =>
          _saveLog(goal: goal, existingLog: log, amount: amount),
    );
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) return _buildScreen(context);
    const foreground = Color(0xFF293330);
    const secondary = Color(0xFF68746D);
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F5F2),
        dividerColor: const Color(0xFFD9E1DA),
        colorScheme: theme.colorScheme.copyWith(
          primary: const Color(0xFF00B993),
          onPrimary: const Color(0xFF102A24),
          surface: const Color(0xFFE6ECE7),
          onSurface: foreground,
          onSurfaceVariant: secondary,
        ),
        textTheme: theme.textTheme
            .apply(bodyColor: foreground, displayColor: foreground)
            .copyWith(
              bodyMedium: theme.textTheme.bodyMedium?.copyWith(
                color: secondary,
              ),
              bodySmall: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
      ),
      child: Builder(builder: _buildScreen),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final goalsAsync = ref.watch(computedSavingsGoalsProvider);
    final goal = goalsAsync.when(
      data: (goals) => goals.firstWhere(
        (g) => g.id == widget.goal.id,
        orElse: () => widget.goal,
      ),
      loading: () => widget.goal,
      error: (error, stack) => widget.goal,
    );

    final logsAsync = ref.watch(savingsLogsProvider(goal.id));
    final settings = ref.watch(settingsProvider);
    final currencyFormat = settings.currency.formatter;
    final accountsAsync = ref.watch(accountProvider);
    Account? linkedAccount;
    if (goal.linkedAccountId != null && accountsAsync.hasValue) {
      try {
        linkedAccount = accountsAsync.value!.firstWhere(
          (a) => a.id == goal.linkedAccountId,
        );
      } catch (_) {}
    }
    final dashboardStats = ref.watch(dashboardStatsProvider);
    double? linkedBalance;
    if (linkedAccount != null) {
      linkedBalance = dashboardStats.accountBalances[linkedAccount.id] ?? 0.0;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const KoinBackButton(),
                  const Gap(8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: TextStyle(
                            fontSize: KoinTypography.sectionTitle,
                            fontWeight: KoinTypography.titleWeight,
                            letterSpacing: KoinTypography.itemTracking,
                            color: AppTheme.textColor(context),
                          ),
                          maxLines:
                              MediaQuery.textScalerOf(context).scale(18) > 24
                              ? 2
                              : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (linkedAccount != null) ...[
                          const Gap(3),
                          Text(
                            linkedAccount.name,
                            key: const ValueKey('savings_account_label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: KoinTypography.small,
                              fontWeight: KoinTypography.supportingWeight,
                              color: AppTheme.textLightColor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap(8),
                  _buildManagementActions(context, goal),
                ],
              ),
            ),
            if (goalsAsync.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Details could not be refreshed. Showing saved details.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(savingsGoalsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGaugeHeader(context, goal, currencyFormat),
                          const Gap(8),
                          _buildQuickActions(
                            context,
                            goal,
                            linkedAccount,
                            linkedBalance,
                          ),
                          if (linkedBalance != null &&
                              goal.currentAmount > linkedBalance)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Reserved savings exceed the account balance. Release savings to match your spending.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.expenseColor(context),
                                  fontSize: KoinTypography.caption,
                                ),
                              ),
                            ),
                          const Gap(28),
                          SavingsRoutineCard(goal: goal),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: _buildActivitySection(
                      context,
                      goal,
                      logsAsync,
                      currencyFormat,
                      linkedAccount,
                      linkedBalance,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final KoinAsyncActionGuard _deleteGuard = KoinAsyncActionGuard();

  Future<void> _deleteGoal(SavingsGoal goal) => _deleteGuard.run(
    context,
    () => _deleteGoalImpl(goal),
    errorTitle: 'Could not delete this item',
  );

  Future<void> _deleteGoalImpl(SavingsGoal goal) async {
    HapticService.medium();
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Delete Goal?',
      description:
          'Are you sure you want to delete this savings goal? This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.expenseColor(context),
      icon: Icons.delete_forever_rounded,
      isDanger: true,
    );
    if (confirmed == true && mounted) {
      await ref.read(savingsGoalsProvider.notifier).deleteGoal(goal.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildQuickActions(
    BuildContext context,
    SavingsGoal goal,
    Account? linkedAccount,
    double? linkedBalance,
  ) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: KoinTypography.fontFamily,
        fontSize: KoinTypography.body,
        fontWeight: KoinTypography.titleWeight,
      ),
    );
    final save = Tooltip(
      message: 'Add Savings',
      child: FilledButton.icon(
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            AppTheme.primaryColor(context),
          ),
          foregroundColor: const WidgetStatePropertyAll(Color(0xFF102A24)),
        ),
        onPressed: () => _showAddLogSheet(
          goal: goal,
          linkedAccount: linkedAccount,
          linkedBalance: linkedBalance,
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Save'),
      ),
    );
    final release = Tooltip(
      message: 'Release savings',
      child: FilledButton.tonalIcon(
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => AppTheme.surfaceColor(context),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppTheme.textLightColor(context)
                : AppTheme.textColor(context),
          ),
        ),
        onPressed: goal.currentAmount > 0
            ? () => _showAddLogSheet(
                goal: goal,
                release: true,
                linkedAccount: linkedAccount,
                linkedBalance: linkedBalance,
              )
            : null,
        icon: const Icon(Icons.south_west_rounded, size: 20),
        label: const Text('Release'),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = MediaQuery.textScalerOf(context).scale(15) > 22;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [save, const Gap(10), release],
          );
        }
        return Row(
          children: [
            Expanded(child: save),
            const Gap(12),
            Expanded(child: release),
          ],
        );
      },
    );
  }

  Widget _buildGaugeHeader(
    BuildContext context,
    SavingsGoal goal,
    NumberFormat currencyFormat,
  ) {
    return Padding(
      key: const ValueKey('savings_balance'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved',
            style: TextStyle(
              color: AppTheme.textLightColor(context),
              fontSize: KoinTypography.body,
            ),
          ),
          const Gap(8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCounter(
              value: goal.currentAmount,
              formatter: currencyFormat.format,
              duration: const Duration(milliseconds: 400),
              style: TextStyle(
                color: AppTheme.textColor(context),
                fontSize: 48,
                fontWeight: Theme.of(context).brightness == Brightness.dark
                    ? KoinTypography.headingWeight
                    : KoinTypography.titleWeight,
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
          ),
          if (goal.hasTarget) ...[
            const Gap(20),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text(
                  'Target',
                  style: TextStyle(color: AppTheme.textLightColor(context)),
                ),
                Text(
                  currencyFormat.format(goal.targetAmount),
                  style: TextStyle(
                    color: AppTheme.textColor(context),
                    fontWeight: KoinTypography.titleWeight,
                  ),
                ),
                Text(
                  '${(goal.progress * 100).toInt()}%',
                  style: TextStyle(
                    color: AppTheme.incomeContentColor(context),
                    fontWeight: KoinTypography.titleWeight,
                  ),
                ),
              ],
            ),
            const Gap(10),
            LinearProgressIndicator(
              value: goal.progress,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              color: AppTheme.primaryColor(context),
              backgroundColor: AppTheme.surfaceLightColor(context),
            ),
            const Gap(8),
            Text(
              '${currencyFormat.format(goal.remainingAmount)} left${goal.remainingDays == null ? '' : ' · ${goal.remainingDays} days remaining'}',
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontSize: KoinTypography.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManagementActions(BuildContext context, SavingsGoal goal) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit goal',
          icon: const Icon(Icons.edit_rounded, size: 24),
          color: AppTheme.textLightColor(context),
          onPressed: () {
            HapticService.light();
            Navigator.push(
              context,
              SlideUpRoute(page: AddSavingsGoalScreen(goal: goal)),
            );
          },
        ),
        IconButton(
          tooltip: 'Delete goal',
          icon: const Icon(Icons.delete_rounded, size: 24),
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.expenseColor(context)
              : const Color(0xFFB8434D),
          onPressed: () => _deleteGoal(goal),
        ),
      ],
    );
  }

  Widget _buildActivitySection(
    BuildContext context,
    SavingsGoal goal,
    AsyncValue<List<SavingsLog>> logsAsync,
    NumberFormat currencyFormat,
    Account? linkedAccount,
    double? linkedBalance,
  ) => SliverMainAxisGroup(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 19,
              fontWeight: Theme.of(context).brightness == Brightness.dark
                  ? FontWeight.w800
                  : KoinTypography.titleWeight,
              color: AppTheme.textColor(context),
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
      logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: KoinActivityEmptyState(
                title: 'No activity yet',
                subtitle: 'Tap "Save" to record your first deposit',
              ),
            );
          }
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildActivityTimeline(
                context,
                goal,
                logs,
                currencyFormat,
                linkedAccount,
                linkedBalance,
              ),
            ),
          );
        },
        loading: () => const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => SliverToBoxAdapter(
          child: KoinErrorState(
            onRetry: () => ref.invalidate(savingsLogsProvider(goal.id)),
          ),
        ),
      ),
    ],
  );
  Widget _buildActivityTimeline(
    BuildContext context,
    SavingsGoal goal,
    List<SavingsLog> logs,
    NumberFormat currencyFormat,
    Account? linkedAccount,
    double? linkedBalance,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < logs.length; index++) ...[
          if (index > 0)
            Divider(
              key: ValueKey('activity-divider-${logs[index].id}'),
              height: 1,
              color: AppTheme.dividerColor(context),
            ),
          if (logs[index].transactionId != null)
            _automaticReleaseTile(context, logs[index], currencyFormat)
          else
            SwipeToDeleteTile(
              key: Key(logs[index].id),
              margin: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: AppTheme.expenseColor(
                context,
              ).withValues(alpha: 0.15),
              iconColor: AppTheme.expenseColor(context),
              icon: Icons.delete_outline_rounded,
              confirmTitle: 'Delete Entry?',
              confirmDescription:
                  'Are you sure you want to delete this savings entry?',
              confirmLabel: 'Delete',
              onDelete: () async {
                await ref
                    .read(savingsGoalsProvider.notifier)
                    .deleteLog(logs[index]);
              },
              child: PressableScale(
                onTap: () {
                  HapticService.light();
                  _showAddLogSheet(
                    goal: goal,
                    log: logs[index],
                    linkedAccount: linkedAccount,
                    linkedBalance: linkedBalance,
                  );
                },
                child: _activityEntryBody(context, logs[index], currencyFormat),
              ),
            ),
        ],
      ],
    );
  }

  Widget _activityEntryBody(
    BuildContext context,
    SavingsLog log,
    NumberFormat money,
  ) {
    final released = log.amount < 0;
    final secondary = AppTheme.textLightColor(context);
    final amount = Text(
      '${released ? '-' : '+'} ${money.format(log.amount.abs())}',
      textAlign: TextAlign.end,
      style: TextStyle(
        color: released
            ? AppTheme.textColor(context)
            : AppTheme.incomeContentColor(context),
        fontSize: KoinTypography.itemAmount,
        fontWeight: KoinTypography.titleWeight,
        letterSpacing: KoinTypography.itemTracking,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              released ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 20,
              color: released
                  ? secondary
                  : AppTheme.incomeContentColor(context),
            ),
          ),
          const Gap(12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(15) > 20;
                final title = Text(
                  released ? 'Released' : 'Saved',
                  style: TextStyle(
                    color: AppTheme.textColor(context),
                    fontSize: KoinTypography.body,
                    fontWeight: KoinTypography.labelWeight,
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stacked) ...[
                      title,
                      const Gap(4),
                      amount,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: title),
                          const Gap(12),
                          Flexible(fit: FlexFit.tight, child: amount),
                        ],
                      ),
                    const Gap(4),
                    Text(
                      '${DateFormat.MMMd().format(log.date)} · ${_formatRelativeTime(log.date)}',
                      style: TextStyle(
                        color: secondary,
                        fontSize: KoinTypography.caption,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _automaticReleaseTile(
    BuildContext context,
    SavingsLog log,
    NumberFormat money,
  ) {
    final textColor = AppTheme.textLightColor(context);
    final showExplanation = _expandedReleaseExplanations.contains(log.id);
    return Column(
      key: Key(log.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _activityEntryBody(context, log, money),
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  if (showExplanation) {
                    _expandedReleaseExplanations.remove(log.id);
                  } else {
                    _expandedReleaseExplanations.add(log.id);
                  }
                }),
                onLongPress: () {},
                child: Semantics(
                  button: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: textColor,
                        ),
                        const Gap(4),
                        Flexible(
                          child: Text(
                            'Auto release · Read only',
                            style: TextStyle(fontSize: 12, color: textColor),
                          ),
                        ),
                        const Gap(4),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: textColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showExplanation) ...[
                const Gap(8),
                Text(
                  'Managed by its transaction. Edit or delete that transaction to update this release.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: textColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
