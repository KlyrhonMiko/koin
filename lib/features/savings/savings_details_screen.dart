import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
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
  Future<void> _saveLog({
    SavingsLog? existingLog,
    required double amount,
  }) async {
    if (existingLog != null) {
      final newLog = SavingsLog(
        id: existingLog.id,
        goalId: existingLog.goalId,
        amount: amount,
        date: existingLog.date,
      );
      await ref
          .read(savingsGoalsProvider.notifier)
          .updateLog(existingLog, newLog);
      HapticService.success();
    } else {
      final log = SavingsLog(
        id: const Uuid().v4(),
        goalId: widget.goal.id,
        amount: amount,
        date: DateTime.now(),
      );

      final wasCompleted = widget.goal.isCompleted;
      await ref.read(savingsGoalsProvider.notifier).addLog(log);
      final isNowCompleted = widget.goal.willComplete(amount);

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
    SavingsLog? log,
    Account? linkedAccount,
    double? linkedBalance,
  }) {
    SavingsLogSheet.show(
      context: context,
      goal: widget.goal,
      log: log,
      linkedAccount: linkedAccount,
      linkedBalance: linkedBalance,
      onSave: (amount) => _saveLog(existingLog: log, amount: amount),
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppTheme.primaryGradient(context),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor(context).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticService.medium();
            _showAddLogSheet(
              linkedAccount: linkedAccount,
              linkedBalance: linkedBalance,
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Add Savings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
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
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFFF6B6B),
                    ),
                    onPressed: () async {
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
                        await ref
                            .read(savingsGoalsProvider.notifier)
                            .deleteGoal(goal.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGaugeHeader(context, goal, currencyFormat),
                    const Gap(16),
                    _buildSavingsNeededSection(context, goal, currencyFormat),
                    const Gap(24),
                    _buildCoachInsightButton(context, goal, currencyFormat),
                    const Gap(32),
                    _buildActivitySection(
                      context,
                      goal,
                      logsAsync,
                      currencyFormat,
                      linkedAccount,
                      linkedBalance,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeHeader(
    BuildContext context,
    SavingsGoal goal,
    NumberFormat currencyFormat,
  ) {
    return KoinSummaryCard(
      shapeStyle: SummaryShapeStyle.savings,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: (goal.isStash && !goal.hasTarget)
                          ? 1.0
                          : goal.progress,
                    ),
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
                              color: Colors.white.withValues(
                                alpha: 0.1,
                              ),
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
          const Gap(24),
          if (!goal.isStash || goal.hasTarget) ...[
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

  Widget _buildCoachInsightButton(
    BuildContext context,
    SavingsGoal goal,
    NumberFormat currencyFormat,
  ) {
    return PressableScale(
      onTap: () async {
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
            await ref
                .read(savingsGoalsProvider.notifier)
                .updateGoal(updatedGoal);

            if (!context.mounted) return;
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
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor(context).withValues(alpha: 0.1),
              AppTheme.primaryColor(context).withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tips_and_updates_rounded,
                size: 20,
                color: AppTheme.primaryColor(context),
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Savings Coach Insight',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor(context),
                    ),
                  ),
                  const Gap(4),
                  Text(
                    'Run scenarios to hit your goal on time.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textColor(context).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.primaryColor(context).withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
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
              BoxShadow(
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
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.4,
              ),
            ),
            const Gap(14),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return _buildEmptyActivity(context);
                }
                return _buildActivityTimeline(
                  context,
                  logs,
                  currencyFormat,
                  linkedAccount,
                  linkedBalance,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        )
        .animate()
        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.95, 0.95),
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildEmptyActivity(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLightColor(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 28,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
            ),
          ),
          const Gap(16),
          Text(
            'No activity yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor(context),
              fontSize: 15,
            ),
          ),
          const Gap(4),
          Text(
            'Tap "Add Savings" to record\nyour first deposit',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline(
    BuildContext context,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline connector
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.25),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 1,
                              color: AppTheme.dividerColor(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Gap(10),
                  // Log card
                  Expanded(
                    child: SwipeToDeleteTile(
                      key: Key(log.id),
                      margin: const EdgeInsets.only(bottom: 10),
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
                        ref.read(savingsGoalsProvider.notifier).deleteLog(log);
                      },
                      child: PressableScale(
                        onTap: () {
                          HapticService.light();
                          _showAddLogSheet(
                            log: log,
                            linkedAccount: linkedAccount,
                            linkedBalance: linkedBalance,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor(context),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
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
                                  Icons.arrow_upward_rounded,
                                  color: AppTheme.incomeColor(context),
                                  size: 16,
                                ),
                              ),
                              const Gap(14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '+ ${currencyFormat.format(log.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppTheme.incomeColor(context),
                                      ),
                                    ),
                                    const Gap(2),
                                    Text(
                                      _formatRelativeTime(log.date),
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
                ],
              ),
            )
            .animate()
            .fade(delay: (index * 60).ms, duration: 350.ms)
            .slideX(begin: 0.04);
      }).toList(),
    );
  }
}
