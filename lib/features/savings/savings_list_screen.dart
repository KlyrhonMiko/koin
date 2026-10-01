import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/savings_details_screen.dart';

class SavingsTab extends ConsumerStatefulWidget {
  final bool showEntranceAnimations;

  const SavingsTab({super.key, required this.showEntranceAnimations});

  @override
  ConsumerState<SavingsTab> createState() => _SavingsTabState();
}

class _SavingsTabState extends ConsumerState<SavingsTab> {
  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(computedSavingsGoalsProvider);
    final settings = ref.watch(settingsProvider);
    final currencyFormat = NumberFormat.simpleCurrency(
      name: settings.currency.code,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: _buildEmptyState(context))],
          );
        }
        return RefreshIndicator(
          onRefresh: () {
            HapticService.light();
            return ref.read(savingsGoalsProvider.notifier).loadGoals();
          },
          color: AppTheme.primaryColor(context),
          backgroundColor: AppTheme.surfaceColor(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildHeroBentoCard(
                    context,
                    goals,
                    currencyFormat,
                    isDark,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Your Goals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      Text(
                        '${goals.length} ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final goal = goals[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildListGoalCard(
                        context,
                        goal,
                        index,
                        currencyFormat,
                        isDark,
                      ),
                    );
                  }, childCount: goals.length),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: _buildAddGoalButton(context),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildHeroBentoCard(
    BuildContext context,
    List<SavingsGoal> goals,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final totalTarget = goals.fold<double>(
      0,
      (sum, g) => sum + (g.targetAmount ?? 0),
    );
    final overallProgress = totalTarget > 0
        ? (totalSaved / totalTarget).clamp(0.0, 1.0)
        : 0.0;

    Widget card = KoinSummaryCard(
      shapeStyle: SummaryShapeStyle.savings,
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
                    'Total Saved',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Gap(6),
                  AnimatedCounter(
                    value: totalSaved,
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
                    tween: Tween<double>(begin: 0, end: overallProgress),
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
              ),
            ],
          ),
          const Gap(24),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
          const Gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Target', totalTarget, currencyFormat),
              _buildMiniStat(
                'Remaining',
                totalTarget - totalSaved,
                currencyFormat,
                alignment: CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.showEntranceAnimations) {
      card = card
          .animate()
          .fade(duration: 400.ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.96, 0.96),
            duration: 400.ms,
            curve: Curves.easeOutCubic,
          );
    }
    return card;
  }

  Widget _buildMiniStat(
    String label,
    double amount,
    NumberFormat fmt, {
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Gap(6),
        AnimatedCounter(
          value: amount,
          formatter: (v) => fmt.format(v),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildListGoalCard(
    BuildContext context,
    SavingsGoal goal,
    int index,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final progressPercent = (goal.progress * 100).toInt();
    final isCompleted = goal.isCompleted;

    final accentColors = [
      AppTheme.primaryColor(context),
      const Color(0xFF6366F1),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];
    final accentColor = accentColors[index % accentColors.length];
    final successGreen = const Color(0xFF10B981);

    Widget card = PressableScale(
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          SlideUpRoute(page: SavingsDetailsScreen(goal: goal)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppTheme.dividerColor(context).withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(4),
                      Text(
                        currencyFormat.format(goal.currentAmount),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? successGreen.withValues(alpha: 0.1)
                        : AppTheme.backgroundColor(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$progressPercent%',
                    style: TextStyle(
                      color: isCompleted
                          ? successGreen
                          : AppTheme.textColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: goal.progress),
                duration: Duration(milliseconds: 800 + (index * 100)),
                curve: Curves.easeOutCubic,
                builder: (context, animatedProgress, _) {
                  return LinearProgressIndicator(
                    value: animatedProgress,
                    backgroundColor: AppTheme.backgroundColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? successGreen : accentColor,
                    ),
                    minHeight: 6,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.showEntranceAnimations) {
      card = card
          .animate(key: ValueKey('goal_${goal.id}_entrance'))
          .fade(delay: (index * 40).ms, duration: 400.ms)
          .slideX(begin: 0.05, curve: Curves.easeOutCubic);
    }
    return card;
  }

  Widget _buildEmptyState(BuildContext context) {
    Widget state = KoinEmptyState.sliver(
      alignment: const Alignment(0, -0.2),
      icon: Icons.savings_outlined,
      iconSize: 40,
      title: 'No dreams yet',
      subtitle:
          'Start your financial journey by\nsetting your first savings goal.',
      action: PressableScale(
        onTap: () {
          Navigator.push(
            context,
            SlideUpRoute(page: const AddSavingsGoalScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.primaryColor(context),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
              Gap(8),
              Text(
                'Create First Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.showEntranceAnimations) {
      state = state
          .animate()
          .fade(delay: 50.ms, duration: 400.ms, curve: Curves.easeOutCubic)
          .slideY(begin: 0.1, curve: Curves.easeOutCubic);
    }
    return state;
  }

  Widget _buildAddGoalButton(BuildContext context) {
    Widget btn = PressableScale(
      onTap: () {
        Navigator.push(
          context,
          SlideUpRoute(page: const AddSavingsGoalScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.8),
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
    );

    if (widget.showEntranceAnimations) {
      btn = btn
          .animate()
          .fade(duration: 400.ms, curve: Curves.easeOutCubic)
          .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutCubic);
    }
    return btn;
  }
}
