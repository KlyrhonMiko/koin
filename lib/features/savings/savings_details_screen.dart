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


class SavingsDetailsScreen extends ConsumerStatefulWidget {
  final SavingsGoal goal;

  const SavingsDetailsScreen({super.key, required this.goal});

  @override
  ConsumerState<SavingsDetailsScreen> createState() => _SavingsDetailsScreenState();
}

class _SavingsDetailsScreenState extends ConsumerState<SavingsDetailsScreen> {
  final _amountController = TextEditingController();

  Future<void> _addLog() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final log = SavingsLog(
      id: const Uuid().v4(),
      goalId: widget.goal.id,
      amount: amount,
      date: DateTime.now(),
    );

    final wasCompleted = widget.goal.progress >= 1.0;
    await ref.read(savingsGoalsProvider.notifier).addLog(log);
    
    // Fanfare logic: if it wasn't completed but now it is
    final currentAmountAfter = widget.goal.currentAmount + amount;
    final isNowCompleted = currentAmountAfter >= widget.goal.targetAmount;

    _amountController.clear();
    
    if (!wasCompleted && isNowCompleted) {
      // Triple pulse fanfare
      HapticService.success();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticService.medium();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticService.heavy();
    } else {
      HapticService.success();
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showAddLogSheet() {
    String currentExpression = '';
    String evaluatedResult = '0';
    _amountController.text = '0';
    
    HapticService.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final settings = ref.read(settingsProvider);
          final hasAmount = currentExpression.isNotEmpty && currentExpression != '0';
          final primaryColor = AppTheme.primaryColor(context);

          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                const Text(
                  'Add Savings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
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
                              color: hasAmount ? primaryColor : primaryColor.withValues(alpha: 0.3),
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
                              color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
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
                      _addLog();
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

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(savingsGoalsProvider);
    final goal = goalsAsync.when(
      data: (goals) => goals.firstWhere((g) => g.id == widget.goal.id, orElse: () => widget.goal),
      loading: () => widget.goal,
      error: (error, stack) => widget.goal,
    );

    final logsAsync = ref.watch(savingsLogsProvider(goal.id));
    final settings = ref.watch(settingsProvider);
    final currencyFormat = NumberFormat.simpleCurrency(name: settings.currency.code);

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
                description: 'Are you sure you want to delete this savings goal? This action cannot be undone.',
                confirmLabel: 'Delete',
                confirmColor: AppTheme.expenseColor(context),
                icon: Icons.delete_forever_rounded,
                isDanger: true,
              );
              if (confirmed == true && mounted) {
                await ref.read(savingsGoalsProvider.notifier).deleteGoal(goal.id);
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
          label: const Text('Add Savings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGaugeHeader(context, goal, currencyFormat),
            const Gap(24),
            _buildSectionHeader(context, 'Savings Needed', Icons.trending_up_rounded),
            const Gap(12),
            _buildCalculationsGrid(context, goal, currencyFormat),
            const Gap(24),
            _buildSectionHeader(context, 'Recent Activity', Icons.history_rounded),
            const Gap(12),
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
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor(context)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildGaugeHeader(BuildContext context, SavingsGoal goal, NumberFormat currencyFormat) {
    final progressPercent = (goal.progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor(context).withValues(alpha: 0.08),
            AppTheme.primaryColor(context).withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor(context).withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Radial gauge
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _RadialGaugePainter(
                progress: goal.progress,
                trackColor: AppTheme.dividerColor(context),
                progressColor: AppTheme.primaryColor(context),
                strokeWidth: 10,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$progressPercent%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor(context),
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'saved',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: 600.ms,
            curve: Curves.elasticOut,
          ),
          const Gap(20),
          // Stats row
          Row(
            children: [
              Expanded(child: _buildStatColumn(context, 'Current', currencyFormat.format(goal.currentAmount), AppTheme.incomeColor(context))),
              Container(width: 1, height: 36, color: AppTheme.dividerColor(context)),
              Expanded(child: _buildStatColumn(context, 'Target', currencyFormat.format(goal.targetAmount), AppTheme.primaryColor(context))),
              Container(width: 1, height: 36, color: AppTheme.dividerColor(context)),
              Expanded(child: _buildStatColumn(context, 'Remaining', currencyFormat.format(goal.remainingAmount), AppTheme.expenseColor(context))),
            ],
          ),
          const Gap(16),
          // Days remaining bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: AppTheme.textLightColor(context).withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text(
                  '${goal.remainingDays} days remaining',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: goal.remainingDays <= 7
                        ? AppTheme.expenseColor(context)
                        : AppTheme.textLightColor(context),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '• ends ${DateFormat.yMMMd().format(goal.endDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.04);
  }

  Widget _buildStatColumn(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textLightColor(context).withValues(alpha: 0.6))),
        const Gap(4),
        FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculationsGrid(BuildContext context, SavingsGoal goal, NumberFormat currencyFormat) {
    return Row(
      children: [
        Expanded(child: _buildCalculationCard(context, 'Daily', currencyFormat.format(goal.dailyNeeded), Icons.today_rounded)),
        const Gap(10),
        Expanded(child: _buildCalculationCard(context, 'Weekly', currencyFormat.format(goal.weeklyNeeded), Icons.view_week_rounded)),
        const Gap(10),
        Expanded(child: _buildCalculationCard(context, 'Monthly', currencyFormat.format(goal.monthlyNeeded), Icons.calendar_month_rounded)),
      ],
    ).animate().fade(delay: 150.ms).slideY(begin: 0.04);
  }

  Widget _buildCalculationCard(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dividerColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor(context)),
          ),
          const Gap(10),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textLightColor(context).withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
          const Gap(4),
          FittedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 32, color: AppTheme.textLightColor(context).withValues(alpha: 0.3)),
          const Gap(12),
          Text(
            'No activity yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textLightColor(context),
            ),
          ),
          const Gap(4),
          Text(
            'Tap "Add Savings" to record your first deposit',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms);
  }

  Widget _buildActivityTimeline(BuildContext context, List<SavingsLog> logs, NumberFormat currencyFormat) {
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
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 18),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor(context),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          color: AppTheme.dividerColor(context),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Log card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.dividerColor(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeColor(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.arrow_upward_rounded, color: AppTheme.incomeColor(context), size: 16),
                      ),
                      const SizedBox(width: 12),
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
                            const SizedBox(height: 2),
                            Text(
                              DateFormat.yMMMd().add_jm().format(log.date),
                              style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.5), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate().fade(delay: (index * 60).ms).slideX(begin: 0.04);
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
