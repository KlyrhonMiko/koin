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
    final summary = ref.watch(savingsSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final currencyFormat = settings.currency.formatter;
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: const KoinSectionHeader(title: 'Savings & goals'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final goal = goals[index];
                    return Padding(
                      key: ValueKey(goal.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            onDelete: () async {
                              HapticService.heavy();
                              await ref
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
                  child: KoinAddButton(
                    label: 'Add savings / goal',
                    onPressed: () => Navigator.push(
                      context,
                      SlideUpRoute(page: const AddSavingsGoalScreen()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          KoinErrorState(onRetry: () => ref.invalidate(savingsGoalsProvider)),
    );
  }

  Widget _buildHeroBentoCard(
    BuildContext context,
    SavingsSummary summary,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    Widget card = KoinSummaryCard(
      shapeStyle: SummaryShapeStyle.savings,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total saved', style: PortfolioCardStyle.summaryLabel),
          const Gap(12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCounter(
              value: summary.totalSaved,
              formatter: currencyFormat.format,
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              style: PortfolioCardStyle.summaryAmount,
            ),
          ),
        ],
      ),
    );

    if (widget.showEntranceAnimations) {
      card = card
          .koinAnimate(
            context,
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onInit: KoinMotion.onInit(context),
          )
          .fade(duration: 400.ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.96, 0.96),
            duration: 400.ms,
            curve: Curves.easeOutCubic,
          );
    }
    return card;
  }

  Widget _buildListGoalCard(
    BuildContext context,
    SavingsGoal goal,
    int index,
    NumberFormat currencyFormat,
  ) {
    final isCompleted = goal.isCompleted;
    final stacked =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(15) > 20;

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
        key: ValueKey('savings-item-card-${goal.id}'),
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
                  flex: stacked ? 1 : 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: KoinTypography.body,
                          fontWeight: KoinTypography.titleWeight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stacked) ...[
                        const Gap(4),
                        Text(
                          currencyFormat.format(goal.currentAmount),
                          style: PortfolioCardStyle.amount(context),
                        ),
                      ],
                      const Gap(4),
                      Text(
                        goal.isStash
                            ? switch (goal.savingsPlan?.frequency) {
                                SavingsFrequency.weekly => 'Weekly savings',
                                SavingsFrequency.fortnightly => 'Every 2 weeks',
                                SavingsFrequency.monthly => 'Monthly savings',
                                null => 'Open-ended savings',
                              }
                            : 'Goal · ${currencyFormat.format(goal.targetAmount)} target',
                        style: PortfolioCardStyle.label(context),
                        maxLines: goal.isStash ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!stacked) ...[
                  const Gap(12),
                  Flexible(
                    fit: FlexFit.tight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        currencyFormat.format(goal.currentAmount),
                        key: ValueKey('savings-item-amount-${goal.id}'),
                        textAlign: TextAlign.end,
                        style: PortfolioCardStyle.amount(context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (goal.hasTarget) ...[
              const Gap(8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: goal.progress),
                  duration: KoinMotion.duration(
                    context,
                    Duration(milliseconds: 800 + (index * 100)),
                  ),
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
          .koinAnimate(
            context,
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onInit: KoinMotion.onInit(context),
            key: ValueKey('goal_${goal.id}_entrance'),
          )
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
              child: Row(
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
          .koinAnimate(
            context,
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onInit: KoinMotion.onInit(context),
          )
          .fade(delay: 50.ms, duration: 400.ms, curve: Curves.easeOutCubic)
          .slideY(begin: 0.1, curve: Curves.easeOutCubic);
    }
    return state;
  }
}
