import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/models/savings/savings_projection.dart';

String contributionPhrase(SavingsFrequency frequency) => switch (frequency) {
  SavingsFrequency.weekly => 'every week',
  SavingsFrequency.fortnightly => 'every 2 weeks',
  SavingsFrequency.monthly => 'every month',
};

/// Solid = recorded savings; lighter fill = estimated future contributions.
class SavingsProjectionBar extends StatelessWidget {
  final double saved;
  final double projected;
  final double scale;
  final NumberFormat format;
  const SavingsProjectionBar({
    super.key,
    required this.saved,
    required this.projected,
    required this.scale,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final actual = scale > 0 ? (saved / scale).clamp(0.0, 1.0) : 0.0;
    final future = scale > 0 ? (projected / scale).clamp(actual, 1.0) : actual;
    final color = AppTheme.incomeContentColor(context);
    return Semantics(
      label:
          'Saved ${format.format(saved)}. Projected ${format.format(projected)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppTheme.surfaceLightColor(context),
                    ),
                  ),
                  FractionallySizedBox(
                    key: const ValueKey('projected_fill'),
                    widthFactor: future,
                    heightFactor: 1,
                    child: ColoredBox(color: color.withValues(alpha: 0.3)),
                  ),
                  FractionallySizedBox(
                    key: const ValueKey('saved_fill'),
                    widthFactor: actual,
                    heightFactor: 1,
                    child: ColoredBox(color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _legend(context, color, 'Saved'),
              _legend(context, color.withValues(alpha: 0.3), 'Projected'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class SavingsProjectionView extends StatefulWidget {
  final SavingsGoal goal;
  final List<SavingsLog> logs;
  final NumberFormat format;
  final bool compact;
  final bool editorPreview;
  final DateTime? today;
  const SavingsProjectionView({
    super.key,
    required this.goal,
    required this.logs,
    required this.format,
    this.compact = false,
    this.editorPreview = false,
    this.today,
  });

  @override
  State<SavingsProjectionView> createState() => _SavingsProjectionViewState();
}

class _SavingsProjectionViewState extends State<SavingsProjectionView> {
  bool _year = false;

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final plan = goal.savingsPlan;
    if (plan == null) return const SizedBox.shrink();
    final today = SavingsPlan.day(widget.today ?? DateTime.now());
    final projection = SavingsProjection(
      goal: goal,
      today: today,
      logs: widget.logs,
    );
    final deadline = !goal.isStash ? goal.endDate : null;
    final horizon =
        deadline != null && !SavingsPlan.day(deadline).isBefore(today)
        ? SavingsPlan.day(deadline)
        : (_year
              ? DateTime(today.year, 12, 31)
              : DateTime(today.year, today.month + 1, 0));
    final projected = projection.totalBy(horizon);
    final completion = projection.completionDate;
    final dateLabel = DateFormat.yMMMd().format(horizon);
    String message;
    if (goal.isCompleted) {
      message =
          'Target reached. You have saved ${widget.format.format(goal.currentAmount)}.';
    } else if (!goal.isStash && goal.hasTarget) {
      message = completion == null
          ? 'Try a higher amount to bring your goal within reach.'
          : 'At ${widget.format.format(plan.amount)} ${contributionPhrase(plan.frequency)}, you could reach your goal by ${DateFormat.yMMMd().format(completion)}.';
    } else {
      message =
          'Set aside ${widget.format.format(plan.amount)} ${contributionPhrase(plan.frequency)} and you could have ${widget.format.format(projected)} by $dateLabel.';
    }
    if (widget.compact) {
      message = goal.isCompleted
          ? 'Target reached'
          : '${widget.format.format(projected)} projected by $dateLabel';
    }
    final needed = deadline == null ? null : projection.requiredBy(deadline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact &&
            (goal.isStash || (!widget.editorPreview && deadline == null)) &&
            !goal.isCompleted) ...[
          KoinChoiceControl(
            key: const ValueKey('projection_horizon'),
            segments: const [
              KoinSegmentItem(label: 'This month'),
              KoinSegmentItem(label: 'This year'),
            ],
            selectedIndex: _year ? 1 : 0,
            onChanged: (index) => setState(() => _year = index == 1),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.editorPreview)
          _resultPanel(
            context,
            plan: plan,
            goal: goal,
            projected: projected,
            completion: completion,
            dateLabel: dateLabel,
            message: message,
          )
        else
          Text(
            message,
            key: const ValueKey('helper_projection_message'),
            style: widget.compact
                ? TextStyle(
                    color: AppTheme.textColor(context),
                    fontSize: KoinTypography.caption,
                    fontWeight: KoinTypography.labelWeight,
                  )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        if (widget.compact && !goal.isCompleted) ...[
          const SizedBox(height: 4),
          Text(
            '${widget.format.format(plan.amount)} ${contributionPhrase(plan.frequency)}',
            style: TextStyle(
              color: AppTheme.textLightColor(context),
              fontSize: KoinTypography.caption,
            ),
          ),
        ],
        if (!widget.compact && !widget.editorPreview && !goal.isStash) ...[
          const SizedBox(height: 12),
          Text(
            '${widget.format.format(projected)} projected by $dateLabel',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
        if (!widget.compact && !widget.editorPreview) ...[
          const SizedBox(height: 12),
          SavingsProjectionBar(
            saved: goal.currentAmount,
            projected: projected,
            scale: goal.hasTarget
                ? max(goal.targetAmount!, goal.currentAmount)
                : max(projected, 1),
            format: widget.format,
          ),
        ],
        if (!widget.compact &&
            !widget.editorPreview &&
            !goal.isCompleted &&
            deadline != null) ...[
          const SizedBox(height: 12),
          Text(
            SavingsPlan.day(deadline).isBefore(today)
                ? 'Your target date has passed. You can choose a new date in Edit.'
                : needed == null
                ? 'Your first contribution is after the target date. Choose an earlier start or a later target date.'
                : 'To reach ${widget.format.format(goal.targetAmount)} by ${DateFormat.yMMMd().format(deadline)}, set aside ${widget.format.format(needed)} ${contributionPhrase(plan.frequency)}.',
          ),
        ],
        if (!widget.compact && !widget.editorPreview) ...[
          const SizedBox(height: 8),
          Text(
            'Estimates follow your plan. Record deposits to update Saved.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _resultPanel(
    BuildContext context, {
    required SavingsPlan plan,
    required SavingsGoal goal,
    required double projected,
    required DateTime? completion,
    required String dateLabel,
    required String message,
  }) {
    final isGoal = !goal.isStash && goal.hasTarget;
    final label = goal.isCompleted
        ? 'Target reached'
        : isGoal
        ? 'Estimated finish'
        : 'Projected savings';
    final value = goal.isCompleted
        ? widget.format.format(goal.currentAmount)
        : isGoal
        ? (completion == null
              ? 'Try a higher amount'
              : DateFormat.yMMMd().format(completion))
        : widget.format.format(projected);
    final valueText = Text(
      value,
      key: const ValueKey('helper_result_value'),
      style: TextStyle(
        color: AppTheme.incomeContentColor(context),
        fontSize: isGoal ? 22 : 24,
        fontWeight: KoinTypography.titleWeight,
        letterSpacing: KoinTypography.itemTracking,
        height: KoinTypography.amountHeight,
      ),
    );
    final supportingStyle = TextStyle(
      color: AppTheme.textLightColor(context),
      fontSize: KoinTypography.caption,
      fontWeight: KoinTypography.labelWeight,
    );
    return Semantics(
      key: const ValueKey('helper_projection_message'),
      label: message,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('helper_result_panel'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: supportingStyle),
            const SizedBox(height: 8),
            if (isGoal)
              valueText
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: valueText,
              ),
            if (!isGoal && !goal.isCompleted) ...[
              const SizedBox(height: 6),
              Text('by $dateLabel', style: supportingStyle),
            ],
            if (!goal.isCompleted) ...[
              const SizedBox(height: 12),
              Text(
                '${widget.format.format(plan.amount)} ${contributionPhrase(plan.frequency)}',
                style: supportingStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
