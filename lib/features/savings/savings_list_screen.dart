import 'dart:math';
import 'package:flutter/material.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/animated_counter.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/savings_details_screen.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

class SavingsListScreen extends ConsumerWidget {
  const SavingsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(computedSavingsGoalsProvider);
    final settings = ref.watch(settingsProvider);
    final currencyFormat = NumberFormat.simpleCurrency(
      name: settings.currency.code,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        Expanded(
          child: goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return _buildEmptyState(context);
              }
              return RefreshIndicator(
                onRefresh: () {
                  HapticService.light();
                  return ref.read(savingsGoalsProvider.notifier).loadGoals();
                },
                color: AppTheme.primaryColor(context),
                backgroundColor: AppTheme.surfaceColor(context),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: goals.length + 2, // +1 hero, +1 add button
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildHeroSummaryCard(
                        context,
                        goals,
                        currencyFormat,
                      );
                    }
                    if (index == goals.length + 1) {
                      return _buildAddGoalButton(context, index);
                    }
                    final goal = goals[index - 1];
                    return _buildGoalCard(context, goal, index, currencyFormat);
                  },
                ),
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
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(color: AppTheme.backgroundColor(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DREAMS',
            style: TextStyle(
              color: AppTheme.textLightColor(context).withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: -0.2),
          const SizedBox(height: 4),
          Text(
            'Savings Tracker',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.textColor(context),
            ),
          ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: -0.2),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard(
    BuildContext context,
    List<SavingsGoal> goals,
    NumberFormat currencyFormat,
  ) {
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final overallProgress = totalTarget > 0
        ? (totalSaved / totalTarget).clamp(0.0, 1.0)
        : 0.0;

    return Container(
          margin: const EdgeInsets.only(bottom: 24),
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
              // Decorative circles for depth
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
                children: [
                  // Top label row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Progress',
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
                          '${goals.length} goal${goals.length == 1 ? '' : 's'}',
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
                  const Gap(20),
                  // Centered radial gauge
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: overallProgress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedProgress, child) {
                      final animatedPercent = (animatedProgress * 100)
                          .toStringAsFixed(0);
                      return SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: _RadialProgressPainter(
                            progress: animatedProgress,
                            trackColor: Colors.white.withValues(alpha: 0.15),
                            progressColor: Colors.white,
                            strokeWidth: 8,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$animatedPercent%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    letterSpacing: -1,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'saved',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
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
                  const Gap(24),
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeroStatAnimated(
                          'Saved',
                          totalSaved,
                          currencyFormat,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildHeroStatAnimated(
                          'Target',
                          totalTarget,
                          currencyFormat,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildHeroStatAnimated(
                          'Remaining',
                          totalTarget - totalSaved,
                          currencyFormat,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fade(duration: 500.ms)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }

  Widget _buildHeroStatAnimated(String label, double amount, NumberFormat fmt) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(4),
        FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedCounter(
              value: amount,
              formatter: (v) => fmt.format(v),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ],
    );
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
                              color: AppTheme.primaryColor(
                                context,
                              ).withValues(alpha: 0.08),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.savings_rounded,
                          size: 56,
                          color: AppTheme.primaryColor(
                            context,
                          ).withValues(alpha: 0.5),
                        ),
                      )
                      .animate()
                      .scale(
                        delay: 200.ms,
                        curve: Curves.easeOutBack,
                        duration: 600.ms,
                      )
                      .fadeIn(),
                  const Gap(28),
                  Text(
                        'No goals yet',
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 300.ms, duration: 400.ms)
                      .fadeIn(),
                  const Gap(8),
                  Text(
                        'Start your savings journey by\ncreating your first goal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 400.ms, duration: 400.ms)
                      .fadeIn(),
                  const Gap(36),
                  PressableScale(
                        onTap: () {
                          Navigator.push(
                            context,
                            SlideUpRoute(page: const AddSavingsGoalScreen()),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppTheme.primaryGradient(context),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: null, // Let PressableScale handle onTap
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Create Your First Goal',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              disabledBackgroundColor: Colors.transparent,
                              disabledForegroundColor: Colors.white,
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 500.ms, duration: 400.ms)
                      .fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddGoalButton(BuildContext context, int index) {
    return PressableScale(
          onTap: () {
            Navigator.push(
              context,
              SlideUpRoute(page: const AddSavingsGoalScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                width: 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: AppTheme.textLightColor(context),
                  size: 20,
                ),
                const Gap(10),
                Text(
                  'Add New Goal',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fade(delay: 300.ms, duration: 400.ms)
        .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildGoalCard(
    BuildContext context,
    SavingsGoal goal,
    int index,
    NumberFormat currencyFormat,
  ) {
    final progressPercent = (goal.progress * 100).toStringAsFixed(0);
    final isCompleted = goal.progress >= 1.0;

    // Accent colors for left strip
    final accentColors = [
      AppTheme.primaryColor(context),
      const Color(0xFF6366F1),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];
    final accentColor = accentColors[index % accentColors.length];

    return PressableScale(
          onTap: () {
            HapticService.light();
            Navigator.push(
              context,
              SlideUpRoute(page: SavingsDetailsScreen(goal: goal)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (isCompleted)
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: name + percentage badge
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Gap(4),
                                  Text(
                                    '${currencyFormat.format(goal.currentAmount)} of ${currencyFormat.format(goal.targetAmount)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textLightColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(12),
                            // Percentage badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$progressPercent%',
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(14),
                        // Animated horizontal progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: goal.progress),
                            duration: Duration(
                              milliseconds: 800 + (index * 100),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedProgress, _) {
                              return LinearProgressIndicator(
                                value: animatedProgress,
                                backgroundColor: accentColor.withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accentColor,
                                ),
                                minHeight: 5,
                              );
                            },
                          ),
                        ),
                        const Gap(12),
                        // Bottom info row
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.5),
                            ),
                            const Gap(4),
                            Text(
                              '${goal.remainingDays}d left',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: goal.remainingDays <= 7
                                    ? AppTheme.expenseColor(context)
                                    : AppTheme.textLightColor(
                                        context,
                                      ).withValues(alpha: 0.5),
                              ),
                            ),
                            const Gap(12),
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
                            const Gap(12),
                            Text(
                              '${currencyFormat.format(goal.dailyNeeded)}/day',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fade(delay: (index * 80).ms, duration: 400.ms)
        .slideY(begin: 0.06, curve: Curves.easeOutCubic);
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
