import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/coach/coach_screen.dart';
import 'package:koin/features/savings/coach/coach_engine.dart';
import 'package:koin/features/savings/widgets/savings_log_sheet.dart';

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
    final currencyFormat = NumberFormat.simpleCurrency(
      name: settings.currency.code,
    );
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
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.textColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (linkedAccount != null) ...[
                          const Gap(2),
                          Row(
                            children: [
                              if (linkedAccount.logoAsset != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.asset(
                                    linkedAccount.logoAsset!,
                                    width: 14,
                                    height: 14,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Icon(
                                  IconUtils.getIcon(
                                    linkedAccount.iconCodePoint,
                                  ),
                                  size: 14,
                                  color: linkedAccount.color,
                                ),
                              const Gap(4),
                              Text(
                                linkedAccount.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textLightColor(
                                    context,
                                  ).withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Savings coach',
                    child: TextButton.icon(
                      onPressed: () => _openCoach(goal),
                      icon: const Icon(
                        Icons.tips_and_updates_rounded,
                        size: 18,
                      ),
                      label: const Text('Coach'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textLightColor(context),
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
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
                          const Gap(24),
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
                          if (goal.dailyNeeded != null) ...[
                            const Gap(16),
                            _buildSavingsNeededSection(
                              context,
                              goal,
                              currencyFormat,
                            ),
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

  Future<void> _deleteGoal(SavingsGoal goal) async {
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
    final actions = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildActionItem(
            context,
            icon: Icons.add_rounded,
            label: 'Save',
            tooltip: 'Add Savings',
            color: AppTheme.primaryColor(context),
            onTap: () => _showAddLogSheet(
              goal: goal,
              linkedAccount: linkedAccount,
              linkedBalance: linkedBalance,
            ),
          ),
        ),
        Expanded(
          child: _buildActionItem(
            context,
            icon: Icons.south_west_rounded,
            label: 'Release',
            tooltip: 'Release savings',
            enabled: goal.currentAmount > 0,
            color: AppTheme.primaryColor(context),
            onTap: () => _showAddLogSheet(
              goal: goal,
              release: true,
              linkedAccount: linkedAccount,
              linkedBalance: linkedBalance,
            ),
          ),
        ),
        Expanded(
          child: _buildActionItem(
            context,
            icon: Icons.edit_rounded,
            label: 'Edit',
            tooltip: 'Edit goal',
            color: AppTheme.textLightColor(context),
            onTap: () {
              HapticService.light();
              Navigator.push(
                context,
                SlideUpRoute(page: AddSavingsGoalScreen(goal: goal)),
              );
            },
          ),
        ),
        Expanded(
          child: _buildActionItem(
            context,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            tooltip: 'Delete goal',
            color: AppTheme.expenseColor(context),
            onTap: () => _deleteGoal(goal),
          ),
        ),
      ],
    );
    if (MediaQuery.disableAnimationsOf(context)) return actions;
    return actions
        .animate()
        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.95, 0.95),
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
    bool enabled = true,
  }) => Semantics(
    button: true,
    enabled: enabled,
    child: Tooltip(
      message: tooltip ?? label,
      child: IgnorePointer(
        ignoring: !enabled,
        child: PressableScale(
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
                child: Icon(
                  icon,
                  color: enabled ? color : color.withValues(alpha: 0.3),
                  size: 22,
                ),
              ),
              const Gap(8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: KoinTypography.small,
                  fontWeight: KoinTypography.labelWeight,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: enabled ? 1 : 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildGaugeHeader(
    BuildContext context,
    SavingsGoal goal,
    NumberFormat currencyFormat,
  ) {
    return KoinSummaryCard(
          shapeStyle: SummaryShapeStyle.savings,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Gap(6),
                        AnimatedCounter(
                          value: goal.currentAmount,
                          formatter: (v) => currencyFormat.format(v),
                          duration: const Duration(milliseconds: 1400),
                          curve: Curves.easeOutCubic,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (goal.hasTarget) const Gap(12),
                  if (goal.hasTarget)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: goal.progress),
                          duration: const Duration(milliseconds: 1400),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: CircularProgressIndicator(
                                    value: 1.0,
                                    strokeWidth: 4,
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: CircularProgressIndicator(
                                    value: val,
                                    strokeWidth: 4,
                                    strokeCap: StrokeCap.round,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${(val * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ).animate().scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),
                ],
              ),
              if (goal.hasTarget) ...[
                const Gap(20),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      context,
                      label: 'Target',
                      value: goal.targetAmount ?? 0.0,
                      formatter: currencyFormat.format,
                      alignment: CrossAxisAlignment.start,
                    ),
                    _buildStatItem(
                      context,
                      label: goal.remainingDays != null
                          ? 'Left (${goal.remainingDays}d)'
                          : 'Left',
                      value: goal.remainingAmount ?? 0.0,
                      formatter: currencyFormat.format,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ],
            ],
          ),
        )
        .animate()
        .fade(duration: 400.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required double value,
    required String Function(double) formatter,
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const Gap(6),
        AnimatedCounter(
          value: value,
          formatter: formatter,
          duration: const Duration(milliseconds: 1000),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _openCoach(SavingsGoal goal) async {
    HapticService.light();
    final CoachSimulationResult? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavingsCoachScreen(goal: goal),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      if (result.newDeadline != goal.endDate ||
          (result.targetAmountOverride != null &&
              result.targetAmountOverride != goal.targetAmount)) {
        final updatedGoal = SavingsGoal(
          id: goal.id,
          name: goal.name,
          targetAmount: result.targetAmountOverride ?? goal.targetAmount,
          currentAmount: goal.currentAmount,
          startDate: goal.startDate,
          endDate: result.newDeadline,
          notes: goal.notes,
          linkedAccountId: goal.linkedAccountId,
          isStash: goal.isStash,
        );
        await ref.read(savingsGoalsProvider.notifier).updateGoal(updatedGoal);

        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final themeColor = AppTheme.primaryColor(context);

        final msg = result.targetAmountOverride != null && goal.isStash
            ? 'Stash plan updated!'
            : 'Deadline updated to ${DateFormat.yMMMd().format(result.newDeadline)}';

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: themeColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildSavingsNeededSection(
    BuildContext context,
    SavingsGoal goal,
    NumberFormat currencyFormat,
  ) {
    if (goal.dailyNeeded == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
              'Savings Needed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.3,
              ),
            )
            .animate()
            .fade(duration: 300.ms, curve: Curves.easeOutCubic)
            .slideY(begin: 0.2, duration: 300.ms, curve: Curves.easeOutCubic),
        const Gap(12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.dividerColor(context).withValues(alpha: 0.4),
            ),
            boxShadow: [
              AppTheme.boxShadow(
                context,
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPlainMetric(
                  context,
                  label: 'Daily',
                  value: goal.dailyNeeded!,
                  formatter: currencyFormat.format,
                  delayMs: 100,
                ),
              ),
              Expanded(
                child: _buildPlainMetric(
                  context,
                  label: 'Weekly',
                  value: goal.weeklyNeeded!,
                  formatter: currencyFormat.format,
                  delayMs: 160,
                ),
              ),
              Expanded(
                child: _buildPlainMetric(
                  context,
                  label: 'Monthly',
                  value: goal.monthlyNeeded!,
                  formatter: currencyFormat.format,
                  delayMs: 220,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlainMetric(
    BuildContext context, {
    required String label,
    required double value,
    required String Function(double) formatter,
    required int delayMs,
  }) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textLightColor(context).withValues(alpha: 0.7),
                letterSpacing: 0.2,
              ),
            ),
            const Gap(2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: AnimatedCounter(
                value: value,
                formatter: formatter,
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        )
        .animate()
        .fade(delay: delayMs.ms, duration: 400.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.15,
          delay: delayMs.ms,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
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
              fontWeight: FontWeight.w800,
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
        error: (err, stack) => SliverToBoxAdapter(child: Text('Error: $err')),
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
      children: logs.asMap().entries.map((entry) {
        final index = entry.key;
        final log = entry.value;
        final isLast = index == logs.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline connector
              SizedBox(
                width: 24,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    if (index > 0)
                      Positioned(
                        top: 0,
                        height: 24,
                        child: Container(
                          key: ValueKey('timeline-above-${log.id}'),
                          width: 1,
                          color: AppTheme.dividerColor(context),
                        ),
                      ),
                    if (!isLast)
                      Positioned(
                        top: 24,
                        bottom: 0,
                        child: Container(
                          key: ValueKey('timeline-below-${log.id}'),
                          width: 1,
                          color: AppTheme.dividerColor(context),
                        ),
                      ),
                    Positioned(
                      top: 20,
                      child: Container(
                        key: ValueKey('timeline-dot-${log.id}'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor(context),
                          shape: BoxShape.circle,
                          boxShadow: [
                            AppTheme.boxShadow(
                              context,
                              color: AppTheme.primaryColor(
                                context,
                              ).withValues(alpha: 0.25),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(10),
              // Log card
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: log.transactionId != null
                      ? _automaticReleaseTile(context, log, currencyFormat)
                      : SwipeToDeleteTile(
                          key: Key(log.id),
                          margin: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(16),
                          backgroundColor: AppTheme.expenseColor(
                            context,
                          ).withValues(alpha: 0.15),
                          iconColor: AppTheme.expenseColor(context),
                          icon: Icons.delete_outline_rounded,
                          confirmTitle: 'Delete Entry?',
                          confirmDescription:
                              'Are you sure you want to delete this savings entry?',
                          confirmLabel: 'Delete',
                          onDelete: () {
                            ref
                                .read(savingsGoalsProvider.notifier)
                                .deleteLog(log);
                          },
                          child: PressableScale(
                            onTap: () {
                              HapticService.light();
                              _showAddLogSheet(
                                goal: goal,
                                log: log,
                                linkedAccount: linkedAccount,
                                linkedBalance: linkedBalance,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor(context),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  AppTheme.boxShadow(
                                    context,
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.incomeColor(
                                        context,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      log.amount < 0
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      color: log.amount < 0
                                          ? AppTheme.textLightColor(context)
                                          : AppTheme.incomeColor(context),
                                      size: 16,
                                    ),
                                  ),
                                  const Gap(14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${log.amount < 0 ? '-' : '+'} ${currencyFormat.format(log.amount.abs())}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: log.amount < 0
                                                ? AppTheme.textLightColor(
                                                    context,
                                                  )
                                                : AppTheme.incomeColor(context),
                                          ),
                                        ),
                                        const Gap(2),
                                        Text(
                                          log.amount < 0
                                              ? 'Released • ${_formatRelativeTime(log.date)}'
                                              : _formatRelativeTime(log.date),
                                          style: TextStyle(
                                            color: AppTheme.textLightColor(
                                              context,
                                            ).withValues(alpha: 0.5),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat.MMMd().format(log.date),
                                    style: TextStyle(
                                      color: AppTheme.textLightColor(
                                        context,
                                      ).withValues(alpha: 0.4),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ).animate().fade(delay: (index * 60).ms, duration: 350.ms).slideX(begin: 0.04);
      }).toList(),
    );
  }

  Widget _automaticReleaseTile(
    BuildContext context,
    SavingsLog log,
    NumberFormat money,
  ) {
    final textColor = AppTheme.textLightColor(context);
    final showExplanation = _expandedReleaseExplanations.contains(log.id);
    return Container(
      key: Key(log.id),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '- ${money.format(log.amount.abs())}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                DateFormat.MMMd().format(log.date),
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ],
          ),
          const Gap(4),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 12, color: textColor),
                  const Gap(4),
                  Flexible(
                    child: Text(
                      'Auto release · Read only',
                      style: TextStyle(fontSize: 12, color: textColor),
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.info_outline_rounded, size: 14, color: textColor),
                ],
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
    );
  }
}
