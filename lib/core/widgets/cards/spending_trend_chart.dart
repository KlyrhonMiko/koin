import 'dart:math' as math;

import 'package:koin/core/utils/motion_policy.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class SpendingTrendChart extends StatefulWidget {
  final List<AppTransaction> expenses;
  final Currency currency;
  final int filterIndex;
  final DateTime? baseDate;

  const SpendingTrendChart({
    super.key,
    required this.expenses,
    required this.currency,
    required this.filterIndex,
    this.baseDate,
  });

  @override
  State<SpendingTrendChart> createState() => _SpendingTrendChartState();
}

class _SpendingTrendChartState extends State<SpendingTrendChart> {
  int _touchedGroupIndex = -1;

  @override
  void didUpdateWidget(covariant SpendingTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterIndex != widget.filterIndex ||
        oldWidget.baseDate != widget.baseDate) {
      _touchedGroupIndex = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expenses.isEmpty) return const SizedBox.shrink();
    final tooltipTheme = TooltipTheme.of(context);
    final tooltipDecoration = tooltipTheme.decoration is BoxDecoration
        ? tooltipTheme.decoration! as BoxDecoration
        : const BoxDecoration();
    final direction = Directionality.of(context);
    final tooltipTextStyle =
        tooltipTheme.textStyle ??
        TextStyle(
          color: AppTheme.textColor(context),
          fontSize: KoinTypography.compact,
          fontWeight: KoinTypography.labelWeight,
        );

    Map<String, double> dailyTotals = {};
    for (var tx in widget.expenses) {
      String dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + tx.amount;
    }

    var sortedDaily =
        dailyTotals.entries
            .map((e) => MapEntry(DateTime.parse(e.key), e.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    DateTime endDate = widget.baseDate ?? DateTime.now();

    List<BarChartGroupData> barGroups = [];
    List<String> bottomLabels = [];
    final dates = <DateTime>[];
    double maxY = 0;

    if (widget.filterIndex == 0) {
      // Week
      final startOfWeek = endDate.subtract(Duration(days: endDate.weekday - 1));

      // Find maxY first
      for (int i = 0; i < 7; i++) {
        DateTime currentDate = startOfWeek.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        double y = dailyTotals[dateKey] ?? 0;
        if (y > maxY) maxY = y;
      }
      maxY = maxY * 1.2;
      if (maxY == 0) maxY = 100;

      for (int i = 0; i < 7; i++) {
        DateTime currentDate = startOfWeek.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        double y = dailyTotals[dateKey] ?? 0;

        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: y,
                color: AppTheme.primaryColor(context),
                width: 16,
                borderRadius: BorderRadius.circular(6),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        );
        bottomLabels.add(DateFormat('E').format(currentDate).substring(0, 1));
        dates.add(currentDate);
      }
    } else if (widget.filterIndex == 2) {
      // Year - group by month
      Map<int, double> monthlyTotals = {};
      for (var tx in widget.expenses) {
        monthlyTotals[tx.date.month] =
            (monthlyTotals[tx.date.month] ?? 0) + tx.amount;
      }

      for (int i = 1; i <= 12; i++) {
        double y = monthlyTotals[i] ?? 0;
        if (y > maxY) maxY = y;
      }
      maxY = maxY * 1.2;
      if (maxY == 0) maxY = 100;

      for (int i = 1; i <= 12; i++) {
        double y = monthlyTotals[i] ?? 0;
        barGroups.add(
          BarChartGroupData(
            x: i - 1,
            barRods: [
              BarChartRodData(
                toY: y,
                color: AppTheme.primaryColor(context),
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
        bottomLabels.add(DateFormat('MMM').format(DateTime(2020, i, 1)));
        dates.add(DateTime(endDate.year, i, 1));
      }
    } else {
      // Keep zero days so horizontal distance represents elapsed time.
      sortedDaily = List.generate(
        DateTime(endDate.year, endDate.month + 1, 0).day,
        (i) {
          final date = DateTime(endDate.year, endDate.month, i + 1);
          return MapEntry(
            date,
            dailyTotals[DateFormat('yyyy-MM-dd').format(date)] ?? 0,
          );
        },
      );
      for (int i = 0; i < sortedDaily.length; i++) {
        if (sortedDaily[i].value > maxY) maxY = sortedDaily[i].value;
      }
      maxY = maxY * 1.2;
      if (maxY == 0) maxY = 100;

      for (int i = 0; i < sortedDaily.length; i++) {
        var entry = sortedDaily[i];
        dates.add(entry.key);
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entry.value,
                color: AppTheme.primaryColor(context),
                width: widget.filterIndex == 1 ? 8 : 4,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
        bottomLabels.add(
          DateFormat(widget.filterIndex == 1 ? 'd' : 'MMM d').format(entry.key),
        );
      }
    }

    final rough = maxY / 4;
    final power = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final fraction = rough / power;
    final interval =
        (fraction <= 1
            ? 1
            : fraction <= 2
            ? 2
            : fraction <= 5
            ? 5
            : 10) *
        power;
    maxY = (maxY / interval).ceil() * interval;
    final total = widget.expenses.fold(0.0, (sum, tx) => sum + tx.amount);
    final chart = Semantics(
      label:
          'Spending trend. Total ${widget.currency.formatter.format(total)}. Use View amounts for dates and values.',
      child: ExcludeSemantics(
        child: Container(
          height: 192,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              AppTheme.boxShadow(
                context,
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: BarChart(
            duration: KoinMotion.duration(
              context,
              const Duration(milliseconds: 240),
            ),
            curve: const Cubic(0.23, 1, 0.32, 1),
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppTheme.dividerColor(context)
                        .withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      int index = val.toInt();
                      if (index < 0 || index >= bottomLabels.length) {
                        return const SizedBox.shrink();
                      }
                      // Avoid crowding on non-weekly filters
                      if (widget.filterIndex != 0 &&
                          index % 2 != 0 &&
                          bottomLabels.length > 7) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          bottomLabels[index],
                          style: TextStyle(
                            color: AppTheme.textLightColor(context),
                            fontSize: KoinTypography.overline,
                            fontWeight: KoinTypography.titleWeight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: interval,
                    getTitlesWidget: (val, meta) {
                      if (val == 0 || val >= maxY) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          NumberFormat.compact().format(val),
                          style: TextStyle(
                            color: AppTheme.textLightColor(context),
                            fontSize: KoinTypography.chartLabel,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchCallback: (FlTouchEvent event, barTouchResponse) {
                  final previousIndex = _touchedGroupIndex;
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      _touchedGroupIndex = -1;
                      return;
                    }
                    _touchedGroupIndex =
                        barTouchResponse.spot!.touchedBarGroupIndex;
                  });

                  final isTouch =
                      event is FlTapDownEvent ||
                      event is FlPanStartEvent ||
                      event is FlPanUpdateEvent ||
                      event is FlLongPressStart ||
                      event is FlLongPressMoveUpdate;
                  if (isTouch &&
                      _touchedGroupIndex >= 0 &&
                      _touchedGroupIndex != previousIndex) {
                    HapticService.selection();
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      tooltipDecoration.color ?? AppTheme.surfaceColor(context),
                  tooltipBorder:
                      tooltipDecoration.border?.top ??
                      BorderSide(color: AppTheme.dividerColor(context)),
                  tooltipBorderRadius:
                      tooltipDecoration.borderRadius?.resolve(direction) ??
                      BorderRadius.circular(12),
                  tooltipPadding:
                      tooltipTheme.padding?.resolve(direction) ??
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  tooltipMargin: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    // Original toY is stored in the barGroups
                    final originalY =
                        barGroups[groupIndex].barRods[rodIndex].toY;
                    return BarTooltipItem(
                      '${widget.filterIndex == 2 ? DateFormat.yMMM().format(dates[groupIndex]) : DateFormat.yMMMEd().format(dates[groupIndex])}\n',
                      tooltipTextStyle,
                      children: [
                        TextSpan(
                          text: widget.currency.formatter.format(originalY),
                          style: tooltipTextStyle,
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: barGroups.asMap().entries.map((entry) {
                final index = entry.key;
                final group = entry.value;
                final isTouched = index == _touchedGroupIndex;
                return BarChartGroupData(
                  x: group.x,
                  barRods: group.barRods.map((rod) {
                    return rod.copyWith(
                      toY: rod.toY,
                      color: isTouched
                          ? AppTheme.primaryColor(context)
                                .withValues(alpha: 0.8)
                          : AppTheme.primaryColor(context),
                      width: rod.width,
                      backDrawRodData: BackgroundBarChartRodData(
                        show: rod.backDrawRodData.show,
                        toY: rod.backDrawRodData.toY,
                        color: isTouched
                            ? AppTheme.dividerColor(context)
                                  .withValues(alpha: 0.3)
                            : rod.backDrawRodData.color,
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chart,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .65,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Spending amounts',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: dates.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(
                              widget.filterIndex == 2
                                  ? DateFormat.yMMM().format(dates[index])
                                  : DateFormat.yMMMEd().format(dates[index]),
                            ),
                            subtitle: Text(
                              widget.currency.formatter.format(
                                barGroups[index].barRods.first.toY,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('View amounts'),
          ),
        ),
      ],
    );
  }
}
