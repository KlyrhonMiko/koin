import 'package:flutter/material.dart';
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
  late DateTime _targetDate;
  late double _targetAmount;

  @override
  void initState() {
    super.initState();
    _weeklySaved = 50.0; // Default weekly stash amount
    _targetDate = DateTime.now().add(const Duration(days: 365));
    _targetAmount = widget.goal.currentAmount + 1000.0;
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
    final currencyFmt = NumberFormat.currency(
      symbol: ref.watch(settingsProvider).currency.symbol,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Stash Simulator', style: TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Mode Toggle
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildToggleOption(
                        context, 
                        title: 'Target Date', 
                        isSelected: _mode == StashSimMode.balance,
                        onTap: () {
                          HapticService.light();
                          setState(() => _mode = StashSimMode.balance);
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildToggleOption(
                        context, 
                        title: 'Target Amount', 
                        isSelected: _mode == StashSimMode.time,
                        onTap: () {
                          HapticService.light();
                          setState(() => _mode = StashSimMode.time);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(40),

              // 2. Big Result Headline
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textLightColor(context),
                  ),
                ),
                const Gap(16),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticService.light();
                        setState(() => _targetDate = _targetDate.subtract(const Duration(days: 30)));
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppTheme.textLightColor(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            DateFormat("MMM d, yyyy").format(_targetDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            "in ${_weeksToTargetDate > 4 ? '${(_weeksToTargetDate / 4).floor()} months' : '$_weeksToTargetDate weeks'}",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticService.light();
                        setState(() => _targetDate = _targetDate.add(const Duration(days: 30)));
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppTheme.textLightColor(context),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  "Adjust Target Amount",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textLightColor(context),
                  ),
                ),
                const Gap(16),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_targetAmount <= widget.goal.currentAmount + 100) return;
                        HapticService.light();
                        setState(() => _targetAmount -= 100);
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppTheme.textLightColor(context),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          currencyFmt.format(_targetAmount),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticService.light();
                        setState(() => _targetAmount += 100);
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppTheme.textLightColor(context),
                    ),
                  ],
                ),
              ],
              
              const Gap(32),

              // 4. Slider
              Text(
                "Stash per week",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textLightColor(context),
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Text(
                    currencyFmt.format(_weeklySaved),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor(context),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppTheme.primaryColor(context),
                  inactiveTrackColor: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                  thumbColor: AppTheme.primaryColor(context),
                  trackHeight: 8,
                ),
                child: Slider(
                  value: _weeklySaved,
                  min: 0,
                  max: 1000,
                  divisions: 100,
                  onChanged: (val) {
                    setState(() => _weeklySaved = val);
                  },
                  onChangeEnd: (_) => HapticService.selection(),
                ),
              ),
              
              const Gap(48),

              // 5. Use this plan
              ElevatedButton(
                onPressed: () {
                  HapticService.success();
                  // Return the simulated deadline depending on mode
                  final dt = _mode == StashSimMode.balance ? _targetDate : (_projectedDate ?? _targetDate);
                  final amt = _mode == StashSimMode.balance ? _projectedBalance : _targetAmount;
                  
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
                      targetAmountOverride: amt
                    )
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Use this plan",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption(BuildContext context, {required String title, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textLightColor(context),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textLightColor(context),
          ),
        ),
        const Gap(4),
        Text(
          fmt.format(_projectedBalance),
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: AppTheme.textColor(context),
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        const Gap(8),
        Text(
          "by ${DateFormat.yMMMMd().format(_targetDate)}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textLightColor(context),
          ),
        ),
        const Gap(4),
        if (pDate == null) 
          Text(
            "Never",
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: AppTheme.expenseColor(context),
              letterSpacing: -1,
              height: 1.1,
            ),
          )
        else ...[
          Text(
            DateFormat.yMMMMd().format(pDate),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppTheme.textColor(context),
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const Gap(8),
          Text(
            "in ${(pDate.difference(DateTime.now()).inDays / 30).floor()} months",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor(context),
            ),
          ),
        ]
      ],
    );
  }
}
