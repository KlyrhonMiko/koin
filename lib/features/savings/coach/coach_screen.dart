import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/coach/coach_engine.dart';
import 'package:koin/features/savings/coach/coach_copy.dart';
import 'package:koin/features/savings/coach/stash_coach_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavingsCoachScreen extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  const SavingsCoachScreen({super.key, required this.goal});

  @override
  ConsumerState<SavingsCoachScreen> createState() => _SavingsCoachScreenState();
}

class _SavingsCoachScreenState extends ConsumerState<SavingsCoachScreen> {
  late CoachEngine _engine;
  late CoachSimulationResult _baseline;

  double _extraPerWeek = 0.0;
  int _deadlineShiftWeeks = 0;

  late double _sliderMax;
  late List<double> _presets;
  late DateTime _latestDateForAxis;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  @override
  void didUpdateWidget(SavingsCoachScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal != widget.goal) {
      _initEngine();
      _extraPerWeek = 0;
      _deadlineShiftWeeks = 0;
    }
  }

  void _initEngine() {
    try {
      _engine = CoachEngine(goal: widget.goal);
      _baseline = _engine.simulate();
      _sliderMax = _engine.calculateSliderMax();
      _presets = _engine.generatePresets(_sliderMax);

      // Determine the fixed axis for the timeline
      DateTime latest = _engine.targetDeadline;
      if (_baseline.projectedFinish != null &&
          _baseline.projectedFinish!.isAfter(latest)) {
        latest = _baseline.projectedFinish!;
      }

      // Also consider if slider is at max, what is the finish date?
      // Actually, maxing the slider makes finish date earlier, so it won't push the axis right.
      // What about max deadline shift? We don't have a max, but let's give the axis a little padding.
      _latestDateForAxis = latest.add(const Duration(days: 30));
    } catch (e) {
      // In case a stash goal gets here somehow
    }
  }

  bool get _hasChanges => _extraPerWeek > 0 || _deadlineShiftWeeks != 0;

  @override
  Widget build(BuildContext context) {
    if (widget.goal.isStash) {
      return StashCoachView(goal: widget.goal);
    }

    if (widget.goal.targetAmount == null || widget.goal.endDate == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Savings Coach")),
        body: const Center(child: Text("This goal cannot be analyzed.")),
      );
    }

    final currencyFmt = NumberFormat.currency(
      symbol: ref.watch(settingsProvider).currency.symbol,
    );

    final headline = CoachCopy.getHeadline(
      _baseline,
      widget.goal.id,
      currencyFmt,
    );

    if (_baseline.status == CoachStatus.completed) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor(context),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 80,
                color: Colors.amber,
              ),
              const Gap(24),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fade().scale(),
            ],
          ),
        ),
      );
    }

    final sim = _engine.simulate(
      extraSavedPerWeek: _extraPerWeek,
      deadlineShiftWeeks: _deadlineShiftWeeks,
    );

    final scenarioText = CoachCopy.getScenarioSentence(
      _baseline,
      sim,
      currencyFmt,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Savings Coach', style: TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Headline
              Text(
                headline,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const Gap(40),

              // 2. Timeline
              SizedBox(
                height: 80,
                child: _TimelineView(
                  baseline: _baseline,
                  sim: sim,
                  today: _engine.today,
                  latestDate: _latestDateForAxis,
                ),
              ),
              const Gap(32),

              // 3. Scenario Sentence
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  scenarioText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor(context),
                    height: 1.4,
                  ),
                ),
              ),
              const Gap(32),

              // 4. Presets
              if (_presets.isNotEmpty) ...[
                Text(
                  "Try a preset",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textLightColor(context),
                  ),
                ),
                const Gap(12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map((preset) {
                    final isSelected = (_extraPerWeek - preset).abs() < 0.01;
                    return ChoiceChip(
                      label: Text('+${currencyFmt.format(preset)}/wk'),
                      selected: isSelected,
                      onSelected: (sel) {
                        if (sel) {
                          HapticService.selection();
                          setState(() => _extraPerWeek = preset);
                        }
                      },
                      selectedColor: AppTheme.primaryColor(
                        context,
                      ).withValues(alpha: 0.2),
                      backgroundColor: AppTheme.surfaceColor(context),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryColor(context)
                            : AppTheme.textColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
                const Gap(32),
              ],

              // 5. Slider
              Text(
                "Extra savings per week",
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
                    '+${currencyFmt.format(_extraPerWeek)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _extraPerWeek > 0
                          ? AppTheme.primaryColor(context)
                          : AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppTheme.primaryColor(context),
                  inactiveTrackColor: AppTheme.primaryColor(
                    context,
                  ).withValues(alpha: 0.1),
                  thumbColor: AppTheme.primaryColor(context),
                  trackHeight: 8,
                ),
                child: Slider(
                  value: _extraPerWeek,
                  min: 0,
                  max: _sliderMax > 0 ? _sliderMax : 100,
                  onChanged: (val) {
                    setState(() => _extraPerWeek = val);
                  },
                  onChangeEnd: (_) => HapticService.selection(),
                ),
              ),
              const Gap(32),

              // 6. Target date row
              Text(
                "Adjust deadline",
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
                      setState(() => _deadlineShiftWeeks--);
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppTheme.textLightColor(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          DateFormat("MMM d, yyyy").format(sim.newDeadline),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_deadlineShiftWeeks != 0)
                          Text(
                            _deadlineShiftWeeks > 0
                                ? "+$_deadlineShiftWeeks weeks"
                                : "$_deadlineShiftWeeks weeks",
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
                      setState(() => _deadlineShiftWeeks++);
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppTheme.textLightColor(context),
                  ),
                ],
              ),
              const Gap(48),

              // 7. Reset and Use this plan
              if (_hasChanges)
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          HapticService.medium();
                          setState(() {
                            _extraPerWeek = 0;
                            _deadlineShiftWeeks = 0;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Reset",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticService.success();
                          Navigator.pop(context, sim);
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fade().slideY(begin: 0.2),

              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  final CoachSimulationResult baseline;
  final CoachSimulationResult sim;
  final DateTime today;
  final DateTime latestDate;

  const _TimelineView({
    required this.baseline,
    required this.sim,
    required this.today,
    required this.latestDate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          // Use a simple tween over a timeline parameter (0 to 1) to animate position
          // We will animate the 'sim' projected finish and deadline shift smoothly.
          // For simplicity, we just rebuild the CustomPaint with the exact dates,
          // but we can animate the dates by converting to milliseconds!
          tween: Tween<double>(
            begin:
                sim.projectedFinish?.millisecondsSinceEpoch.toDouble() ??
                latestDate.millisecondsSinceEpoch.toDouble(),
            end:
                sim.projectedFinish?.millisecondsSinceEpoch.toDouble() ??
                latestDate.millisecondsSinceEpoch.toDouble(),
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, animatedProjMs, child) {
            final animProjFinish = sim.projectedFinish != null
                ? DateTime.fromMillisecondsSinceEpoch(animatedProjMs.toInt())
                : null;

            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _TimelinePainter(
                today: today,
                latestDate: latestDate,
                baselineTarget: baseline.newDeadline,
                baselineProjected: baseline.projectedFinish,
                simTarget: sim.newDeadline,
                simProjected: animProjFinish,
                simStatus: sim.status,
                theme: Theme.of(context),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final DateTime today;
  final DateTime latestDate;
  final DateTime baselineTarget;
  final DateTime? baselineProjected;
  final DateTime simTarget;
  final DateTime? simProjected;
  final CoachStatus simStatus;
  final ThemeData theme;

  _TimelinePainter({
    required this.today,
    required this.latestDate,
    required this.baselineTarget,
    required this.baselineProjected,
    required this.simTarget,
    required this.simProjected,
    required this.simStatus,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalMs = latestDate.difference(today).inMilliseconds;
    if (totalMs <= 0) return;

    double getX(DateTime date) {
      if (date.isBefore(today)) return 0;
      if (date.isAfter(latestDate)) return size.width;
      final ms = date.difference(today).inMilliseconds;
      return (ms / totalMs) * size.width;
    }

    final centerY = size.height / 2;

    // 1. Draw base axis
    final axisPaint = Paint()
      ..color = theme.dividerColor.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), axisPaint);

    // 2. Draw stretch between target and finish by status
    if (simProjected != null) {
      final targetX = getX(simTarget);
      final projX = getX(simProjected!);

      Color statusColor;
      switch (simStatus) {
        case CoachStatus.ahead:
        case CoachStatus.onTrack:
          statusColor = const Color(0xFF10B981); // emerald
          break;
        case CoachStatus.behind:
          statusColor = const Color(0xFFF59E0B); // amber
          break;
        case CoachStatus.atRisk:
        case CoachStatus.overdue:
          statusColor = const Color(0xFFEF4444); // red
          break;
        default:
          statusColor = theme.primaryColor;
      }

      final stretchPaint = Paint()
        ..color = statusColor.withValues(alpha: 0.3)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(min(targetX, projX), centerY),
        Offset(max(targetX, projX), centerY),
        stretchPaint,
      );
    }

    // 3. Tick for target date
    final targetX = getX(simTarget);
    final tickPaint = Paint()
      ..color = theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(targetX, centerY - 8),
      Offset(targetX, centerY + 8),
      tickPaint,
    );

    // text for target
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Target',
        style: TextStyle(
          color: theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(targetX - textPainter.width / 2, centerY - 24),
    );

    // 4. Hollow marker for baseline projected finish
    if (baselineProjected != null) {
      final baseProjX = getX(baselineProjected!);
      final hollowPaint = Paint()
        ..color = theme.dividerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(baseProjX, centerY), 5, hollowPaint);
    }

    // 5. Dot for projected finish
    if (simProjected != null) {
      final projX = getX(simProjected!);
      final dotPaint = Paint()
        ..color = theme.primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(projX, centerY), 6, dotPaint);

      // text for finish
      final finishText = TextPainter(
        text: TextSpan(
          text: 'Finish',
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      finishText.layout();
      finishText.paint(
        canvas,
        Offset(projX - finishText.width / 2, centerY + 12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.simTarget != simTarget ||
        oldDelegate.simProjected != simProjected ||
        oldDelegate.simStatus != simStatus;
  }
}
