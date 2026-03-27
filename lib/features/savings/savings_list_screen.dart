import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/savings_details_screen.dart';

class SavingsListScreen extends ConsumerWidget {
  const SavingsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);
    final settings = ref.watch(settingsProvider);
    final currencyFormat = NumberFormat.simpleCurrency(name: settings.currency.code);

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return _buildEmptyState(context);
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                itemCount: goals.length + 2, // +1 hero, +1 add button
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeroSummaryCard(context, goals, currencyFormat);
                  }
                  if (index == goals.length + 1) {
                    return _buildAddGoalButton(context, index);
                  }
                  final goal = goals[index - 1];
                  return _buildGoalCard(context, goal, index, currencyFormat);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Savings Tracker',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.textColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard(BuildContext context, List<SavingsGoal> goals, NumberFormat currencyFormat) {
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final overallProgress = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
    final progressPercent = (overallProgress * 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor(context),
            AppTheme.primaryColor(context).withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _RadialProgressPainter(
                progress: overallProgress,
                trackColor: Colors.white.withValues(alpha: 0.2),
                progressColor: Colors.white,
                strokeWidth: 7,
              ),
              child: Center(
                child: Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Saved',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(totalSaved),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'of ${currencyFormat.format(totalTarget)} across ${goals.length} goal${goals.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.06);
  }

  Widget _buildEmptyState(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: const Alignment(0, -0.3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(Icons.savings_rounded, size: 56, color: AppTheme.primaryColor(context).withValues(alpha: 0.6)),
                  ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),
                  const SizedBox(height: 24),
                  Text(
                    'No goals yet',
                    style: TextStyle(color: AppTheme.textColor(context), fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ).animate().slideY(begin: 0.2, delay: 300.ms, duration: 400.ms).fadeIn(),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first goal to see it here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 14),
                  ).animate().slideY(begin: 0.2, delay: 400.ms, duration: 400.ms).fadeIn(),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: AppTheme.primaryGradient(context),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddSavingsGoalScreen()),
                        ),
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: const Text('Create Your First Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ).animate().slideY(begin: 0.2, delay: 500.ms, duration: 400.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddGoalButton(BuildContext context, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddSavingsGoalScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor(context).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.primaryColor(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Add New Goal',
              style: TextStyle(
                color: AppTheme.primaryColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(delay: (index * 80).ms).slideY(begin: 0.08);
  }

  Widget _buildGoalCard(BuildContext context, SavingsGoal goal, int index, NumberFormat currencyFormat) {
    final progressPercent = (goal.progress * 100).toStringAsFixed(0);

    // Pick a color based on goal index for the accent
    final accentColors = [
      AppTheme.primaryColor(context),
      const Color(0xFF6366F1),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];
    final accentColor = accentColors[index % accentColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SavingsDetailsScreen(goal: goal)),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Circular progress
              SizedBox(
                width: 52,
                height: 52,
                child: CustomPaint(
                  painter: _RadialProgressPainter(
                    progress: goal.progress,
                    trackColor: accentColor.withValues(alpha: 0.12),
                    progressColor: accentColor,
                    strokeWidth: 5,
                  ),
                  child: Center(
                    child: Text(
                      '$progressPercent%',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyFormat.format(goal.currentAmount)} of ${currencyFormat.format(goal.targetAmount)}',
                      style: TextStyle(fontSize: 13, color: AppTheme.textLightColor(context)),
                    ),
                    const SizedBox(height: 10),
                    // Mini stats row
                    Row(
                      children: [
                        _buildChip(context, 'Daily', currencyFormat.format(goal.dailyNeeded)),
                        const SizedBox(width: 6),
                        _buildChip(context, 'Weekly', currencyFormat.format(goal.weeklyNeeded)),
                      ],
                    ),
                  ],
                ),
              ),
              // End date
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textLightColor(context).withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Text(
                    '${goal.remainingDays}d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: goal.remainingDays <= 7
                          ? AppTheme.expenseColor(context)
                          : AppTheme.textLightColor(context).withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    'left',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textLightColor(context).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(delay: (index * 80).ms).slideY(begin: 0.06);
  }

  Widget _buildChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLightColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(fontSize: 9, color: AppTheme.textLightColor(context).withValues(alpha: 0.6)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RadialProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RadialProgressPainter({
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
  bool shouldRepaint(covariant _RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
