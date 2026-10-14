import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/widgets/savings_log_sheet.dart';
import 'widgets/savings_routine_card.dart';
import 'widgets/savings_projection_view.dart' show contributionPhrase;

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
    return _buildScreen(context);
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
                            fontSize: KoinTypography.screenTitle,
                            fontWeight: KoinTypography.headingWeight,
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
                          _buildLinkedAccount(context, linkedAccount),
                        ],
                      ],
                    ),
                  ),
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGaugeHeader(context, goal, currencyFormat),
                          const Gap(20),
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
                                  color: AppTheme.expenseContentColor(context),
                                  fontSize: KoinTypography.caption,
                                ),
                              ),
                            ),
                          if (!goal.isStash && goal.hasTarget) ...[
                            const Gap(24),
                            _buildGoalDetails(context, goal, currencyFormat),
                          ] else if (goal.isStash) ...[
                            const Gap(24),
                            SavingsRoutineCard(goal: goal),
                          ],
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

  Widget _buildLinkedAccount(BuildContext context, Account account) {
    final fallback = Icon(
      IconUtils.getIcon(account.iconCodePoint),
      size: 14,
      color: account.color,
    );
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 16,
            height: 16,
            child: account.logoAsset != null
                ? Image.asset(
                    account.logoAsset!,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => fallback,
                  )
                : fallback,
          ),
        ),
        const Gap(6),
        Expanded(
          child: Text(
            account.name,
            key: const ValueKey('savings_account_label'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: KoinTypography.small,
              fontWeight: KoinTypography.supportingWeight,
              color: AppTheme.textLightColor(context),
            ),
          ),
        ),
      ],
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
    final actions = [
      _buildManagementAction(
        context,
        tooltip: 'Add Savings',
        label: 'Save',
        icon: Icons.add_rounded,
        color: AppTheme.incomeContentColor(context),
        onPressed: () => _showAddLogSheet(
          goal: goal,
          linkedAccount: linkedAccount,
          linkedBalance: linkedBalance,
        ),
      ),
      _buildManagementAction(
        context,
        tooltip: 'Release savings',
        label: 'Release',
        icon: Icons.south_west_rounded,
        color: AppTheme.textColor(context),
        onPressed: goal.currentAmount > 0
            ? () => _showAddLogSheet(
                goal: goal,
                release: true,
                linkedAccount: linkedAccount,
                linkedBalance: linkedBalance,
              )
            : null,
      ),
      _buildManagementAction(
        context,
        tooltip: 'Edit goal',
        label: 'Edit',
        icon: Icons.edit_rounded,
        color: AppTheme.textLightColor(context),
        onPressed: () {
          HapticService.light();
          Navigator.push(
            context,
            SlideUpRoute(page: AddSavingsGoalScreen(goal: goal)),
          );
        },
      ),
      _buildManagementAction(
        context,
        tooltip: 'Delete goal',
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        color: AppTheme.expenseContentColor(context),
        onPressed: () => _deleteGoal(goal),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            MediaQuery.textScalerOf(context).scale(12) > 18 ||
                constraints.maxWidth < 280
            ? 2
            : 4;
        return Wrap(
          runSpacing: 20,
          children: [
            for (final action in actions)
              SizedBox(width: constraints.maxWidth / columns, child: action),
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
    const foreground = Colors.white;
    return KoinSummaryCard(
      key: const ValueKey('savings_balance'),
      shapeStyle: SummaryShapeStyle.savings,
      borderRadius: KoinShape.summary,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total saved', style: KoinTypography.summaryLabelStyle),
          const Gap(8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCounter(
              value: goal.currentAmount,
              formatter: currencyFormat.format,
              duration: const Duration(milliseconds: 400),
              style: KoinTypography.summaryAmountStyle,
            ),
          ),
          if (goal.isStash && goal.hasTarget) ...[
            const Gap(20),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text(
                  'Target',
                  style: TextStyle(color: foreground.withValues(alpha: 0.75)),
                ),
                Text(
                  currencyFormat.format(goal.targetAmount),
                  style: TextStyle(
                    color: foreground,
                    fontWeight: KoinTypography.titleWeight,
                  ),
                ),
                Text(
                  '${(goal.progress * 100).toInt()}%',
                  style: TextStyle(
                    color: foreground,
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
              color: foreground,
              backgroundColor: foreground.withValues(alpha: 0.15),
            ),
            const Gap(8),
            Text(
              '${currencyFormat.format(goal.remainingAmount)} left${goal.remainingDays == null ? '' : ' · ${goal.remainingDays} days remaining'}',
              style: TextStyle(
                color: foreground.withValues(alpha: 0.75),
                fontSize: KoinTypography.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalDetails(
    BuildContext context,
    SavingsGoal goal,
    NumberFormat format,
  ) {
    final secondary = TextStyle(
      color: AppTheme.textLightColor(context),
      fontSize: KoinTypography.small,
    );
    final plan = goal.savingsPlan;
    final days = goal.remainingDays;
    return Column(
      key: const ValueKey('goal_saving_pace'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KoinSectionHeader(
          title: 'Goal progress',
          subtitle: goal.endDate == null
              ? null
              : 'By ${DateFormat.yMMMd().format(goal.endDate!)}',
          trailing: plan == null
              ? null
              : TextButton(
                  onPressed: () =>
                      SavingsRoutineCard.editPlan(context, ref, goal),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textLightColor(context),
                    textStyle: const TextStyle(
                      fontFamily: KoinTypography.fontFamily,
                      fontSize: KoinTypography.caption,
                      fontWeight: KoinTypography.titleWeight,
                    ),
                  ),
                  child: const Text('Edit schedule'),
                ),
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Target ${format.format(goal.targetAmount)}',
                style: TextStyle(
                  color: AppTheme.textColor(context),
                  fontSize: KoinTypography.body,
                  fontWeight: KoinTypography.titleWeight,
                ),
              ),
            ),
            const Gap(12),
            Text('${(goal.progress * 100).toInt()}%', style: secondary),
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
          goal.isCompleted
              ? 'Target reached'
              : '${format.format(goal.remainingAmount)} left${days != null && days > 0 ? ' · $days days remaining' : ''}',
          style: secondary,
        ),
        if (!goal.isCompleted) ...[
          if (plan != null) ...[
            const Gap(16),
            Text(
              'Scheduled: ${format.format(plan.amount)} ${contributionPhrase(plan.frequency)}',
              style: secondary,
            ),
          ],
          if (days != null && days > 0) ...[
            const Gap(20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(12) > 18
                    ? 1
                    : 3;
                return Wrap(
                  runSpacing: 16,
                  children: [
                    for (final rate in [
                      ('Per day', goal.dailyNeeded!),
                      ('Per week', goal.weeklyNeeded!),
                      ('Per month', goal.monthlyNeeded!),
                    ])
                      SizedBox(
                        width: constraints.maxWidth / columns,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rate.$1, style: secondary),
                              const Gap(6),
                              Text(
                                format.format(rate.$2),
                                style: TextStyle(
                                  color: AppTheme.textColor(context),
                                  fontSize: KoinTypography.itemAmount,
                                  fontWeight: KoinTypography.titleWeight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ] else ...[
            const Gap(12),
            Text(
              days == null
                  ? 'Add a deadline to see how much to save.'
                  : 'Deadline reached',
              style: secondary,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildManagementAction(
    BuildContext context, {
    required String tooltip,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            fixedSize: const Size(54, 54),
            backgroundColor: AppTheme.surfaceColor(context),
            foregroundColor: color,
            disabledForegroundColor: AppTheme.textLightColor(
              context,
            ).withValues(alpha: 0.4),
            shape: const CircleBorder(),
          ),
          icon: Icon(icon, size: 22),
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
          child: const KoinSectionHeader(title: 'Recent activity'),
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
      '${released ? '-' : '+'}${money.format(log.amount.abs())}',
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  (released ? secondary : AppTheme.incomeContentColor(context))
                      .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              released ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 20,
              color: released
                  ? secondary
                  : AppTheme.incomeContentColor(context),
            ),
          ),
          const Gap(14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 220 ||
                    MediaQuery.textScalerOf(context).scale(15) > 20;
                final title = Text(
                  released ? 'Released' : 'Saved',
                  style: TextStyle(
                    color: AppTheme.textColor(context),
                    fontSize: KoinTypography.body,
                    fontWeight: KoinTypography.titleWeight,
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
                        fontSize: KoinTypography.small,
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
          padding: const EdgeInsets.only(left: 54, bottom: 14),
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
