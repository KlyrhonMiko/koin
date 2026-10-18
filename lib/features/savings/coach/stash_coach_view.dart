import 'package:flutter/material.dart';

import 'coach_controls.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/coach/coach_engine.dart'; // for result

enum StashSimMode { balance, time }

class StashCoachView extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  const StashCoachView({super.key, required this.goal});

  @override
  ConsumerState<StashCoachView> createState() => _StashCoachViewState();
}

class _StashCoachViewState extends ConsumerState<StashCoachView> {
  StashSimMode _mode = StashSimMode.balance;

  late double _weeklySaved;
  late double _sliderMax;
  late DateTime _targetDate;
  late double _targetAmount;

  @override
  void initState() {
    super.initState();
    _weeklySaved = widget.goal.savingsPlan == null
        ? 50.0
        : widget.goal.savingsPlan!.amount /
              switch (widget.goal.savingsPlan!.frequency) {
                SavingsFrequency.weekly => 1.0,
                SavingsFrequency.fortnightly => 2.0,
                SavingsFrequency.monthly => 52 / 12,
              }; // Default weekly stash amount
    _sliderMax = _weeklySaved > 1000 ? _weeklySaved * 1.5 : 1000;
    _targetDate = DateTime.now().add(const Duration(days: 365));
    _targetAmount =
        widget.goal.targetAmount ?? widget.goal.currentAmount + 1000.0;
    if (_targetAmount <= widget.goal.currentAmount) {
      _targetAmount = widget.goal.currentAmount + 100.0;
    }
  }

  int get _weeksToTargetDate {
    final diff = _targetDate.difference(DateTime.now()).inDays;
    return diff > 0 ? (diff / 7).ceil() : 0;
  }

  double get _projectedBalance {
    return widget.goal.currentAmount + (_weeklySaved * _weeksToTargetDate);
  }

  DateTime? get _projectedDate {
    if (_weeklySaved <= 0) return null;
    final remaining = _targetAmount - widget.goal.currentAmount;
    if (remaining <= 0) return DateTime.now();
    final weeks = remaining / _weeklySaved;
    return DateTime.now().add(Duration(days: (weeks * 7).ceil()));
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = ref.watch(settingsProvider).currency.formatter;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Choose an amount'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KoinSpacing.screenInset,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Mode Toggle
              KoinChoiceControl(
                segments: const [
                  KoinSegmentItem(label: 'Target Date'),
                  KoinSegmentItem(label: 'Target Amount'),
                ],
                selectedIndex: _mode.index,
                onChanged: (index) =>
                    setState(() => _mode = StashSimMode.values[index]),
              ),
              const Gap(40),

              // 2. Big Result Headline
              AnimatedSwitcher(
                duration: KoinMotion.duration(
                  context,
                  const Duration(milliseconds: 300),
                ),
                child: _mode == StashSimMode.balance
                    ? _buildBalanceHeadline(currencyFmt)
                    : _buildTimeHeadline(currencyFmt),
              ),

              const Gap(40),

              // 3. Mode Specific Inputs
              if (_mode == StashSimMode.balance) ...[
                Text(
                  "Adjust Target Date",
                  style: TextStyle(
                    fontSize: KoinTypography.caption,
                    fontWeight: KoinTypography.titleWeight,
                    color: AppTheme.textLightColor(context),
                  ),
                ),
                const Gap(16),
                CoachStepper(
                  onDecrease: () {
                    HapticService.light();
                    setState(
                      () => _targetDate = _targetDate.subtract(
                        const Duration(days: 30),
                      ),
                    );
                  },
                  onIncrease: () {
                    HapticService.light();
                    setState(
                      () => _targetDate = _targetDate.add(
                        const Duration(days: 30),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        DateFormat("MMM d, yyyy").format(_targetDate),
                        style: const TextStyle(
                          fontSize: KoinTypography.itemTitle,
                          fontWeight: KoinTypography.titleWeight,
                        ),
                      ),
                      Text(
                        "in ${_weeksToTargetDate > 4 ? '${(_weeksToTargetDate / 4).floor()} months' : '$_weeksToTargetDate weeks'}",
                        style: TextStyle(
                          fontSize: KoinTypography.small,
                          color: AppTheme.primaryColor(context),
                          fontWeight: KoinTypography.labelWeight,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  "Adjust Target Amount",
                  style: TextStyle(
                    fontSize: KoinTypography.caption,
                    fontWeight: KoinTypography.titleWeight,
                    color: AppTheme.textLightColor(context),
                  ),
                ),
                const Gap(16),
                CoachStepper(
                  onDecrease: () {
                    if (_targetAmount <= widget.goal.currentAmount + 100) {
                      return;
                    }
                    HapticService.light();
                    setState(() => _targetAmount -= 100);
                  },
                  onIncrease: () {
                    HapticService.light();
                    setState(() => _targetAmount += 100);
                  },
                  child: Center(
                    child: Text(
                      currencyFmt.format(_targetAmount),
                      style: const TextStyle(
                        fontSize: KoinTypography.sectionTitle,
                        letterSpacing: KoinTypography.headingTracking,
                        fontWeight: KoinTypography.headingWeight,
                      ),
                    ),
                  ),
                ),
              ],

              const Gap(32),

              // 4. Slider
              Text(
                "Save per week",
                style: TextStyle(
                  fontSize: KoinTypography.caption,
                  fontWeight: KoinTypography.titleWeight,
                  color: AppTheme.textLightColor(context),
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Text(
                    currencyFmt.format(_weeklySaved),
                    style: TextStyle(
                      fontSize: KoinTypography.sectionTitle,
                      letterSpacing: KoinTypography.headingTracking,
                      fontWeight: KoinTypography.headingWeight,
                      color: AppTheme.primaryColor(context),
                    ),
                  ),
                ],
              ),
              CoachAmountSlider(
                value: _weeklySaved,
                max: _sliderMax,
                divisions: 100,
                onChanged: (value) => setState(() => _weeklySaved = value),
              ),

              const Gap(48),

              // 5. Use this amount
              ElevatedButton(
                onPressed: _weeklySaved <= 0
                    ? null
                    : () {
                        HapticService.success();
                        // Return the simulated deadline depending on mode
                        final dt = _mode == StashSimMode.balance
                            ? _targetDate
                            : (_projectedDate ?? _targetDate);
                        final amt = _mode == StashSimMode.balance
                            ? _projectedBalance
                            : _targetAmount;

                        // Reusing CoachSimulationResult structure to pass back new params
                        Navigator.pop(
                          context,
                          CoachSimulationResult(
                            status: CoachStatus.onTrack,
                            newDeadline: dt,
                            weeklyPace: _weeklySaved,
                            projectedFinish: dt,
                            daysLate: 0,
                            weeklyAmountRequired: _weeklySaved,
                            extraSavedPerWeek: 0,
                            deadlineShiftWeeks: 0,
                            targetAmountOverride: _mode == StashSimMode.time
                                ? amt
                                : null,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor(context),
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Use this amount",
                  style: TextStyle(
                    fontSize: KoinTypography.itemTitle,
                    fontWeight: KoinTypography.titleWeight,
                  ),
                ),
              ),
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceHeadline(NumberFormat fmt) {
    return Column(
      key: const ValueKey('balance'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "You'll have",
          style: TextStyle(
            fontSize: KoinTypography.sectionTitle,
            letterSpacing: KoinTypography.headingTracking,
            fontWeight: KoinTypography.headingWeight,
            color: AppTheme.textLightColor(context),
          ),
        ),
        const Gap(4),
        Text(
          fmt.format(_projectedBalance),
          style: TextStyle(
            fontSize: KoinTypography.summaryAmount,
            fontWeight: KoinTypography.headingWeight,
            color: AppTheme.textColor(context),
            letterSpacing: KoinTypography.amountTracking,
            height: KoinTypography.amountHeight,
          ),
        ),
        const Gap(8),
        Text(
          "by ${DateFormat.yMMMMd().format(_targetDate)}",
          style: TextStyle(
            fontSize: KoinTypography.itemTitle,
            fontWeight: KoinTypography.labelWeight,
            color: AppTheme.primaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeHeadline(NumberFormat fmt) {
    final pDate = _projectedDate;
    return Column(
      key: const ValueKey('time'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "You'll reach ${fmt.format(_targetAmount)}",
          style: TextStyle(
            fontSize: KoinTypography.sectionTitle,
            letterSpacing: KoinTypography.headingTracking,
            fontWeight: KoinTypography.headingWeight,
            color: AppTheme.textLightColor(context),
          ),
        ),
        const Gap(4),
        if (pDate == null)
          Text(
            "Never",
            style: TextStyle(
              fontSize: KoinTypography.summaryAmount,
              fontWeight: KoinTypography.headingWeight,
              color: AppTheme.expenseColor(context),
              letterSpacing: KoinTypography.amountTracking,
              height: KoinTypography.amountHeight,
            ),
          )
        else ...[
          Text(
            DateFormat.yMMMMd().format(pDate),
            style: TextStyle(
              fontSize: KoinTypography.summaryAmount,
              fontWeight: KoinTypography.headingWeight,
              color: AppTheme.textColor(context),
              letterSpacing: KoinTypography.amountTracking,
              height: KoinTypography.amountHeight,
            ),
          ),
          const Gap(8),
          Text(
            "in ${(pDate.difference(DateTime.now()).inDays / 30).floor()} months",
            style: TextStyle(
              fontSize: KoinTypography.itemTitle,
              fontWeight: KoinTypography.labelWeight,
              color: AppTheme.primaryColor(context),
            ),
          ),
        ],
      ],
    );
  }
}
