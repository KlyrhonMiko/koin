import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/savings_details_screen.dart';

class SavingsListScreen extends ConsumerWidget {
  const SavingsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Tracker'),
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return _buildGoalCard(context, goal, index);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddSavingsGoalScreen()),
        ),
        label: const Text('New Goal', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.savings_outlined, size: 48, color: AppTheme.textLightColor(context).withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(
            'No savings goals yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textLightColor(context)),
          ),
          const SizedBox(height: 6),
          Text(
            'Start by creating your first goal!',
            style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, SavingsGoal goal, int index) {
    final currencyFormat = NumberFormat.simpleCurrency();
    final dateFormat = DateFormat.yMMMd();
    final progressPercent = (goal.progress * 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$progressPercent%',
                      style: TextStyle(
                        color: AppTheme.primaryColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${currencyFormat.format(goal.currentAmount)} / ${currencyFormat.format(goal.targetAmount)}',
                    style: TextStyle(fontSize: 14, color: AppTheme.textLightColor(context)),
                  ),
                  Text(
                    'Ends ${dateFormat.format(goal.endDate)}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textLightColor(context).withValues(alpha: 0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor: AppTheme.dividerColor(context),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor(context)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(context, 'Daily', currencyFormat.format(goal.dailyNeeded)),
                  Container(width: 1, height: 28, color: AppTheme.dividerColor(context)),
                  _buildMiniStat(context, 'Weekly', currencyFormat.format(goal.weeklyNeeded)),
                  Container(width: 1, height: 28, color: AppTheme.dividerColor(context)),
                  _buildMiniStat(context, 'Monthly', currencyFormat.format(goal.monthlyNeeded)),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(delay: (index * 80).ms).slideY(begin: 0.08);
  }

  Widget _buildMiniStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textLightColor(context).withValues(alpha: 0.6))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
