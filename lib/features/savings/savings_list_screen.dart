import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/savings_details_screen.dart';
import 'widgets/savings_projection_view.dart';

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
    final summary = ref.watch(savingsSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final currencyFormat = NumberFormat.simpleCurrency(
      name: settings.currency.code,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return goalsAsync.when(
      data: (loadedGoals) {
        final goals = [...loadedGoals]
          ..sort((a, b) => _group(a).compareTo(_group(b)));
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
                    summary,
                    currencyFormat,
                    isDark,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final goal = goals[index];
                    return Padding(
                      key: ValueKey(goal.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (index == 0 ||
                              _group(goals[index - 1]) != _group(goal))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      goal.isStash
                                          ? 'Your savings'
                                          : 'Your goals',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  if (goal.isStash)
                                    TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        SlideUpRoute(
                                          page: const AddSavingsGoalScreen(
                                            initialSavings: true,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Add savings'),
                                    ),
                                ],
                              ),
                            ),
                          SwipeToDeleteTile(
                            key: Key('dismiss_goal_${goal.id}'),
                            borderRadius: BorderRadius.circular(
                              PortfolioCardStyle.radius,
                            ),
                            fillRoundedCorners: true,
                            backgroundColor: AppTheme.errorColor(context),
                            icon: Icons.delete_rounded,
                            confirmTitle: 'Delete Goal?',
                            confirmDescription:
                                'Are you sure you want to delete "${goal.name}"? This action cannot be undone.',
                            onDelete: () {
                              HapticService.heavy();
                              ref
                                  .read(savingsGoalsProvider.notifier)
                                  .deleteGoal(goal.id);
                            },
                            child: _buildListGoalCard(
                              context,
                              goal,
                              index,
                              currencyFormat,
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: goals.length),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KoinSpacing.screenInset,
                    0,
                    KoinSpacing.screenInset,
                    124,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!goals.any((goal) => goal.isStash))
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            SlideUpRoute(
                              page: const AddSavingsGoalScreen(
                                initialSavings: true,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.savings_outlined),
                          label: const Text('Add savings'),
                        ),
                      _buildAddGoalButton(context),
                    ],
                  ),
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
    SavingsSummary summary,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final totalSaved = summary.totalSaved;
    final totalTarget = summary.totalTarget;
    final overallProgress = summary.overallProgress;

    Widget card = KoinSummaryCard(
      shapeStyle: SummaryShapeStyle.defaultStyle,
      padding: const EdgeInsets.symmetric(
        horizontal: KoinSpacing.summaryInset,
        vertical: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Saved', style: PortfolioCardStyle.summaryLabel),
                    const Gap(12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedCounter(
                        value: totalSaved,
                        formatter: (v) => currencyFormat.format(v),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        style: PortfolioCardStyle.summaryAmount,
                      ),
                    ),
                  ],
                ),
              ),
              if (totalTarget > 0) ...[
                const Gap(12),
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
            ],
          ),
          if (totalTarget > 0) ...[
            const Gap(24),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildMiniStat(
                    'Goal targets',
                    totalTarget,
                    currencyFormat,
                  ),
                ),
                Expanded(
                  child: _buildMiniStat(
                    'Goals remaining',
                    summary.goalRemaining,
                    currencyFormat,
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
          ],
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
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Gap(6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedCounter(
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
        ),
      ],
    );
  }

  Widget _buildListGoalCard(
    BuildContext context,
    SavingsGoal goal,
    int index,
    NumberFormat currencyFormat,
  ) {
    final progressPercent = (goal.progress * 100).toInt();
    final isCompleted = goal.isCompleted;

    final accentColor = AppTheme.primaryColor(context);
    final successGreen = AppTheme.incomeContentColor(context);
    final iconColor = isCompleted ? successGreen : accentColor;

    Widget card = PressableScale(
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          SlideUpRoute(page: SavingsDetailsScreen(goal: goal)),
        );
      },
      child: Container(
        padding: PortfolioCardStyle.padding,
        decoration: PortfolioCardStyle.decoration(context),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: PortfolioCardStyle.iconSize,
                  height: PortfolioCardStyle.iconSize,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      PortfolioCardStyle.iconRadius,
                    ),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_rounded
                        : goal.isStash
                        ? Icons.savings_outlined
                        : Icons.flag_outlined,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: PortfolioCardStyle.label(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(4),
                      Text(
                        currencyFormat.format(goal.currentAmount),
                        style: PortfolioCardStyle.amount(context),
                      ),
                    ],
                  ),
                ),
                const Gap(12),
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
                    goal.hasTarget ? '$progressPercent%' : 'Savings',
                    style: TextStyle(
                      color: isCompleted
                          ? successGreen
                          : AppTheme.textColor(context),
                      fontWeight: KoinTypography.labelWeight,
                      fontSize: KoinTypography.small,
                    ),
                  ),
                ),
              ],
            ),
            if (goal.savingsPlan != null &&
                ref.watch(savingsLogsProvider(goal.id)).asData != null) ...[
              const Gap(12),
              SavingsProjectionView(
                goal: goal,
                logs: ref.watch(savingsLogsProvider(goal.id)).requireValue,
                format: currencyFormat,
                compact: true,
              ),
            ] else if (goal.hasTarget) ...[
              const Gap(8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: goal.progress),
                  duration: Duration(milliseconds: 800 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedProgress, _) {
                    return LinearProgressIndicator(
                      value: animatedProgress,
                      backgroundColor: AppTheme.surfaceLightColor(context),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted ? successGreen : accentColor,
                      ),
                      minHeight: 4,
                    );
                  },
                ),
              ),
            ],
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

  int _group(SavingsGoal goal) => goal.isStash ? 0 : 1;

  Widget _buildEmptyState(BuildContext context) {
    Widget state = KoinEmptyState.sliver(
      icon: Icons.savings_outlined,
      title: 'Start saving for what matters',
      subtitle:
          'Create a goal or an open-ended savings pot.\nUse Savings Helper to see what you could save.',
      action: Column(
        children: [
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
                borderRadius: BorderRadius.circular(PortfolioCardStyle.radius),
                color: AppTheme.primaryColor(context),
                boxShadow: [
                  AppTheme.boxShadow(
                    context,
                    color: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.3),
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
          const Gap(12),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              SlideUpRoute(
                page: const AddSavingsGoalScreen(initialSavings: true),
              ),
            ),
            icon: const Icon(Icons.savings_outlined),
            label: const Text('Create savings'),
          ),
        ],
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
    Widget btn = KoinAddButton(
      label: 'Add new goal',
      onPressed: () {
        Navigator.push(
          context,
          SlideUpRoute(page: const AddSavingsGoalScreen()),
        );
      },
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
