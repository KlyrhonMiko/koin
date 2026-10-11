import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
import 'savings_log_sheet.dart';
import 'savings_plan_editor.dart';
import 'savings_projection_view.dart';

class SavingsRoutineCard extends ConsumerWidget {
  final SavingsGoal goal;
  const SavingsRoutineCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = goal.savingsPlan;
    final fmt = NumberFormat.simpleCurrency(
      name: ref.watch(settingsProvider).currency.code,
    );
    final logs = ref.watch(savingsLogsProvider(goal.id));
    final progress = logs.asData == null || plan == null
        ? null
        : plan.progress(logs.requireValue, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Savings Helper',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => _edit(context, ref),
                child: Text(plan == null ? 'Set up' : 'Edit plan'),
              ),
            ],
          ),
          if (plan != null && logs.isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            )
          else if (plan != null && logs.hasError)
            Row(
              children: [
                const Expanded(
                  child: Text('Could not load your contributions.'),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(savingsLogsProvider(goal.id)),
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (plan != null) ...[
            SavingsProjectionView(
              goal: goal,
              logs: logs.requireValue,
              format: fmt,
              compact: true,
            ),
            if (progress != null && !goal.isCompleted) ...[
              const SizedBox(height: 12),
              Text(
                '${progress.isDue ? "Next contribution: today" : "Next contribution: ${DateFormat.yMMMd().format(progress.nextDate)}"} · ${fmt.format(progress.amountDue)}',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: progress.isDue
                      ? () => SavingsLogSheet.show(
                          context: context,
                          goal: goal,
                          initialAmount: goal.hasTarget
                              ? progress.amountDue.clamp(
                                  0,
                                  goal.remainingAmount!,
                                )
                              : progress.amountDue,
                          onSave: (amount) => ref
                              .read(savingsGoalsProvider.notifier)
                              .addLog(
                                SavingsLog(
                                  id: const Uuid().v4(),
                                  goalId: goal.id,
                                  amount: amount,
                                  date: DateTime.now(),
                                  note: 'Savings plan contribution',
                                ),
                              ),
                        )
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Set aside'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await SavingsPlanEditor.open(
      context,
      initial: goal.savingsPlan,
      goal: goal,
    );
    if (result == null || !context.mounted) return;
    try {
      final current = ref
          .read(savingsGoalsProvider)
          .value
          ?.where((g) => g.id == goal.id)
          .firstOrNull;
      if (current == null) return;
      await ref
          .read(savingsGoalsProvider.notifier)
          .updateGoal(
            current.copyWith(
              endDate: current.isStash ? DateTime(1970) : result.deadline,
              savingsPlan: result.plan,
              clearSavingsPlan: result.plan == null,
            ),
            preserveBalance: true,
          );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your plan. Try again.')),
        );
      }
    }
  }
}
