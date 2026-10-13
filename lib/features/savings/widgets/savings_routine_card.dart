import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'savings_plan_editor.dart';
import 'package:koin/core/models/savings/savings_projection.dart';
import 'savings_projection_view.dart' show contributionPhrase;

class SavingsRoutineCard extends ConsumerWidget {
  final SavingsGoal goal;
  const SavingsRoutineCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = goal.savingsPlan;
    final format = ref.watch(settingsProvider).currency.formatter;
    final logs = ref.watch(savingsLogsProvider(goal.id));
    final today = SavingsPlan.day(DateTime.now());
    final secondary = TextStyle(
      fontFamily: KoinTypography.fontFamily,
      color: AppTheme.textLightColor(context),
      fontSize: KoinTypography.caption,
    );
    final edit = TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(64, 48),
        alignment: Alignment.centerRight,
        foregroundColor: AppTheme.textLightColor(context),
        textStyle: secondary.copyWith(fontWeight: KoinTypography.titleWeight),
      ),
      onPressed: () => editPlan(context, ref, goal),
      child: Text(plan == null ? 'Set up savings plan' : 'Edit plan'),
    );
    if (plan == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KoinSectionHeader(title: 'Savings plan'),
          const SizedBox(height: 8),
          Text(
            'Choose an amount and a schedule to keep saving.',
            style: secondary,
          ),
          Align(alignment: Alignment.centerLeft, child: edit),
        ],
      );
    }
    final progress = logs.asData == null
        ? null
        : plan.progress(logs.requireValue, today);
    final deadline = goal.isStash ? null : goal.endDate;
    final horizon =
        deadline != null && !SavingsPlan.day(deadline).isBefore(today)
        ? SavingsPlan.day(deadline)
        : DateTime(today.year, today.month + 1, 0);
    final projected = logs.asData == null
        ? null
        : SavingsProjection(
            goal: goal,
            today: today,
            logs: logs.requireValue,
          ).totalBy(horizon);
    return Column(
      key: const ValueKey('savings_plan_summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KoinSectionHeader(
          title: 'Savings plan',
          subtitle: goal.isCompleted
              ? null
              : '${format.format(plan.amount)} ${contributionPhrase(plan.frequency)}',
          trailing: edit,
        ),
        const SizedBox(height: 20),
        if (logs.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(),
          )
        else if (logs.hasError)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Could not load your contributions.',
                  style: secondary,
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(savingsLogsProvider(goal.id)),
                child: const Text('Retry'),
              ),
            ],
          )
        else if (goal.isCompleted)
          Text(
            'Target reached',
            key: const ValueKey('helper_projection_message'),
            style: secondary,
          )
        else if (progress != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final next = _metric(
                context,
                label: 'Next contribution',
                value: format.format(progress.amountDue),
                detail:
                    '${progress.isDue ? 'Due' : 'Next:'} ${DateFormat.MMMd().format(progress.nextDate)}',
              );
              final projection = _metric(
                context,
                label: 'Projected total',
                value: format.format(projected),
                detail: 'by ${DateFormat.yMMMd().format(horizon)}',
                key: const ValueKey('helper_projection_message'),
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [next, const SizedBox(height: 20), projection],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: next),
                  const SizedBox(width: 24),
                  Expanded(child: projection),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    required String detail,
    Key? key,
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: AppTheme.textLightColor(context),
          fontSize: KoinTypography.caption,
          fontWeight: KoinTypography.labelWeight,
          letterSpacing: KoinTypography.itemTracking,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          color: AppTheme.textColor(context),
          fontSize: KoinTypography.itemAmount,
          fontWeight: KoinTypography.titleWeight,
          letterSpacing: KoinTypography.itemTracking,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        detail,
        style: TextStyle(
          color: AppTheme.textLightColor(context),
          fontSize: KoinTypography.small,
        ),
      ),
    ],
  );
  static Future<void> editPlan(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) async {
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
