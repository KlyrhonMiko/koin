import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/models/savings_log.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:uuid/uuid.dart';

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

    await ref.read(savingsGoalsProvider.notifier).addLog(log);
    _amountController.clear();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showAddLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(20),
            const Text('Add Savings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const Gap(24),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppTheme.primaryGradient(context),
                ),
                child: ElevatedButton(
                  onPressed: _addLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add Savings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
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
      error: (_, __) => widget.goal,
    );

    final logsAsync = ref.watch(savingsLogsProvider(goal.id));
    final currencyFormat = NumberFormat.simpleCurrency();

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Goal'),
                  content: const Text('Are you sure you want to delete this savings goal?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                await ref.read(savingsGoalsProvider.notifier).deleteGoal(goal.id);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressCard(context, goal),
            const Gap(24),
            const Text(
              'Savings Needed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Gap(12),
            _buildCalculationsGrid(context, goal),
            const Gap(24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: _showAddLogSheet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Savings', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const Gap(8),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.dividerColor(context)),
                    ),
                    child: Text(
                      'No activity yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textLightColor(context)),
                    ),
                  );
                }
                return Column(
                  children: logs.map((log) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.dividerColor(context)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor(context).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.add_rounded, color: AppTheme.primaryColor(context), size: 18),
                        ),
                        title: Text(
                          currencyFormat.format(log.amount),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        subtitle: Text(
                          DateFormat.yMMMd().format(log.date),
                          style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 12),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, SavingsGoal goal) {
    final currencyFormat = NumberFormat.simpleCurrency();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Progress', style: TextStyle(fontSize: 14, color: AppTheme.textLightColor(context))),
              Text(
                '${(goal.progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor(context),
                ),
              ),
            ],
          ),
          const Gap(16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 12,
              backgroundColor: AppTheme.dividerColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor(context)),
            ),
          ),
          const Gap(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGoalStat(context, 'Current', currencyFormat.format(goal.currentAmount)),
              _buildGoalStat(context, 'Target', currencyFormat.format(goal.targetAmount)),
              _buildGoalStat(context, 'Remaining', currencyFormat.format(goal.remainingAmount)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textLightColor(context).withValues(alpha: 0.6))),
        const Gap(4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCalculationsGrid(BuildContext context, SavingsGoal goal) {
    final currencyFormat = NumberFormat.simpleCurrency();
    return Row(
      children: [
        Expanded(child: _buildCalculationCard(context, 'Daily', currencyFormat.format(goal.dailyNeeded), Icons.today_rounded)),
        const Gap(10),
        Expanded(child: _buildCalculationCard(context, 'Weekly', currencyFormat.format(goal.weeklyNeeded), Icons.view_week_rounded)),
        const Gap(10),
        Expanded(child: _buildCalculationCard(context, 'Monthly', currencyFormat.format(goal.monthlyNeeded), Icons.calendar_month_rounded)),
      ],
    );
  }

  Widget _buildCalculationCard(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor(context)),
          const Gap(8),
          Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textLightColor(context).withValues(alpha: 0.6))),
          const Gap(4),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
