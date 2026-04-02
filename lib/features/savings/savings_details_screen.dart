import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/models/savings_log.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/numpad.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/widgets/animated_counter.dart';

class SavingsDetailsScreen extends ConsumerStatefulWidget {
  final SavingsGoal goal;

  const SavingsDetailsScreen({super.key, required this.goal});

  @override
  ConsumerState<SavingsDetailsScreen> createState() =>
      _SavingsDetailsScreenState();
}

class _SavingsDetailsScreenState extends ConsumerState<SavingsDetailsScreen> {
  final _amountController = TextEditingController();

  Future<void> _saveLog({SavingsLog? existingLog}) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

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

      final wasCompleted = widget.goal.progress >= 1.0;
      await ref.read(savingsGoalsProvider.notifier).addLog(log);

      final currentAmountAfter = widget.goal.currentAmount + amount;
      final isNowCompleted = currentAmountAfter >= widget.goal.targetAmount;

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

    _amountController.clear();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showAddLogSheet({SavingsLog? log}) {
    String currentExpression = log != null
        ? log.amount.toString().replaceFirst(RegExp(r'\.0$'), '')
        : '';
    String evaluatedResult = log != null ? log.amount.toString() : '0';
    _amountController.text = evaluatedResult;

    HapticService.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final settings = ref.read(settingsProvider);
          final hasAmount =
              currentExpression.isNotEmpty && currentExpression != '0';
          final primaryColor = AppTheme.primaryColor(context);

          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Gap(12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(24),
                Text(
                  log != null ? 'Edit Savings' : 'Add Savings',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const Gap(32),

                // Hero Amount Display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        settings.currency.code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: primaryColor.withValues(alpha: 0.5),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Gap(4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${settings.currency.symbol} ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: primaryColor.withValues(alpha: 0.4),
                            ),
                          ),
                          Text(
                            currentExpression.isEmpty ? '0' : currentExpression,
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: hasAmount
                                  ? primaryColor
                                  : primaryColor.withValues(alpha: 0.3),
                              letterSpacing: -1.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                      if (currentExpression.contains(RegExp(r'[+\-*/]')))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '= ${settings.currency.symbol}$evaluatedResult',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      const Gap(12),
                      Container(
                        width: 48,
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),

                const Gap(32),

                NumPad(
                  compact: true,
                  initialValue: currentExpression,
                  onValueChanged: (expression, result) {
                    setModalState(() {
                      currentExpression = expression;
                      evaluatedResult = result;
                      _amountController.text = result;
                    });
                  },
                  onDone: () {
                    if (double.tryParse(_amountController.text) != null &&
                        double.parse(_amountController.text) > 0) {
                      _saveLog(existingLog: log);
                    } else {
                      HapticService.error();
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
    final goalsAsync = ref.watch(savingsGoalsProvider);
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            HapticService.light();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
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
            _showAddLogSheet();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGaugeHeader(context, goal, currencyFormat),
            const Gap(28),
            _buildSavingsNeededSection(context, goal, currencyFormat),
            const Gap(28),
            _buildActivitySection(context, goal, logsAsync, currencyFormat),
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
    final primaryColor = AppTheme.primaryColor(context);

    return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Radial gauge with subtle glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.08),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: goal.progress),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedProgress, child) {
                    final animatedPercent = (animatedProgress * 100)
                        .toStringAsFixed(1);
                    return SizedBox(
                      width: 160,
                      height: 160,
                      child: CustomPaint(
                        painter: _RadialGaugePainter(
                          progress: animatedProgress,
                          trackColor: AppTheme.dividerColor(context),
                          progressColor: primaryColor,
                          strokeWidth: 10,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedCounter(
                                value: double.parse(animatedPercent),
                                formatter: (v) =>
                                    '${v.toStringAsFixed(v >= 100 ? 0 : 1)}%',
                                duration: const Duration(milliseconds: 400),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                  letterSpacing: -1,
                                  height: 1.1,
                                ),
                              ),
                              const Gap(2),
                              Text(
                                'completed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textLightColor(
                                    context,
                                  ).withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ).animate().scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.0, 1.0),
                duration: 600.ms,
                curve: Curves.elasticOut,
              ),
              const Gap(28),
              // Stats row with colored dots
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      color: AppTheme.incomeColor(context),
                      label: 'Saved',
                      value: goal.currentAmount,
                      formatter: currencyFormat.format,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppTheme.dividerColor(context),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      color: primaryColor,
                      label: 'Target',
                      value: goal.targetAmount,
                      formatter: currencyFormat.format,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppTheme.dividerColor(context),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      color: AppTheme.expenseColor(context),
                      label: 'Left',
                      value: goal.remainingAmount,
                      formatter: currencyFormat.format,
                    ),
                  ),
                ],
              ),
              const Gap(20),
              // Days remaining pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLightColor(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: goal.remainingDays <= 7
                          ? AppTheme.expenseColor(context)
                          : AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: 0.6),
                    ),
                    const Gap(8),
                    Text(
                      '${goal.remainingDays} days left',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: goal.remainingDays <= 7
                            ? AppTheme.expenseColor(context)
                            : AppTheme.textColor(context),
                      ),
                    ),
                    const Gap(8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'ends ${DateFormat.yMMMd().format(goal.endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fade(duration: 400.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildStatItem(
    BuildContext context, {
    required Color color,
    required String label,
    required double value,
    required String Function(double) formatter,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Gap(6),
        FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedCounter(
              value: value,
              formatter: formatter,
              duration: const Duration(milliseconds: 1000),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsNeededSection(
    BuildContext context,
    SavingsGoal goal,
    NumberFormat currencyFormat,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Savings Needed',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.4,
              ),
            ),
            const Gap(14),
            Row(
              children: [
                Expanded(
                  child: _buildNeededCard(
                    context,
                    label: 'Daily',
                    value: goal.dailyNeeded,
                    formatter: currencyFormat.format,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: _buildNeededCard(
                    context,
                    label: 'Weekly',
                    value: goal.weeklyNeeded,
                    formatter: currencyFormat.format,
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: _buildNeededCard(
                    context,
                    label: 'Monthly',
                    value: goal.monthlyNeeded,
                    formatter: currencyFormat.format,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .fade(delay: 150.ms, duration: 400.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  Widget _buildNeededCard(
    BuildContext context, {
    required String label,
    required double value,
    required String Function(double) formatter,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored accent bar at top
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(6),
          FittedBox(
            child: AnimatedCounter(
              value: value,
              formatter: formatter,
              duration: const Duration(milliseconds: 1000),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(
    BuildContext context,
    SavingsGoal goal,
    AsyncValue<List<SavingsLog>> logsAsync,
    NumberFormat currencyFormat,
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
                return _buildActivityTimeline(context, logs, currencyFormat);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        )
        .animate()
        .fade(delay: 250.ms, duration: 400.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
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
                    child: Dismissible(
                      key: Key(log.id),
                      direction: DismissDirection.endToStart,
                      onUpdate: (details) {
                        if (details.reached && !details.previousReached) {
                          HapticService.selection();
                        }
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseColor(
                            context,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.expenseColor(context),
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        HapticService.medium();
                        final confirmed = await ConfirmationSheet.show(
                          context: context,
                          title: 'Delete Entry?',
                          description:
                              'Are you sure you want to delete this savings entry?',
                          confirmLabel: 'Delete',
                          confirmColor: AppTheme.expenseColor(context),
                          icon: Icons.delete_forever_rounded,
                          isDanger: true,
                        );
                        return confirmed ?? false;
                      },
                      onDismissed: (_) {
                        ref.read(savingsGoalsProvider.notifier).deleteLog(log);
                      },
                      child: PressableScale(
                        onTap: () {
                          HapticService.light();
                          _showAddLogSheet(log: log);
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

class _RadialGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RadialGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
