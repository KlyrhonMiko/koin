import 'dart:math' as math;

import 'package:koin/core/icons.dart';

import 'package:koin/core/utils/motion_policy.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

List<MapEntry<DateTime, double>> _spendingTrendAmounts(
  List<AppTransaction> expenses,
  int filterIndex,
  DateTime baseDate,
) {
  final start = AnalysisPeriod.fromIndex(filterIndex).dateRange(baseDate).start;
  final count = filterIndex == 0
      ? 7
      : filterIndex == 2
      ? 12
      : DateTime(baseDate.year, baseDate.month + 1, 0).day;
  final totals = <DateTime, double>{
    for (var i = 0; i < count; i++)
      (filterIndex == 2
              ? DateTime(start.year, i + 1)
              : DateTime(start.year, start.month, start.day + i)):
          0,
  };
  for (final transaction in expenses) {
    final date = transaction.date;
    final key = filterIndex == 2
        ? DateTime(date.year, date.month)
        : DateTime(date.year, date.month, date.day);
    if (totals.containsKey(key)) {
      totals[key] = totals[key]! + transaction.amount;
    }
  }
  return totals.entries.toList();
}

DateTimeRange _spendingTrendRange(DateTime start, int filterIndex) {
  final end = filterIndex == 2
      ? DateTime(start.year, start.month + 1)
      : DateTime(start.year, start.month, start.day + 1);
  return DateTimeRange(
    start: start,
    end: end.subtract(const Duration(microseconds: 1)),
  );
}

class SpendingAmountsButton extends StatelessWidget {
  final List<AppTransaction> expenses;
  final Currency currency;
  final int filterIndex;
  final DateTime? baseDate;
  final ValueChanged<DateTimeRange>? onPeriodSelected;

  const SpendingAmountsButton({
    super.key,
    required this.expenses,
    required this.currency,
    required this.filterIndex,
    this.baseDate,
    this.onPeriodSelected,
  });

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: AppTheme.textLightColor(context),
      overlayColor: AppTheme.primaryColor(context),
      minimumSize: const Size(48, 48),
    ),
    child: const Text('View amounts'),
    onPressed: () {
      final amounts = _spendingTrendAmounts(
        expenses,
        filterIndex,
        baseDate ?? DateTime.now(),
      );
      showModalBottomSheet<void>(
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
                    itemCount: amounts.length,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(
                        filterIndex == 2
                            ? DateFormat.yMMM().format(amounts[index].key)
                            : DateFormat.yMMMEd().format(amounts[index].key),
                      ),
                      subtitle: Text(
                        currency.formatter.format(amounts[index].value),
                      ),
                      trailing: onPeriodSelected == null
                          ? null
                          : const Icon(KoinIcons.caretRight),
                      onTap: onPeriodSelected == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              onPeriodSelected!(
                                _spendingTrendRange(
                                  amounts[index].key,
                                  filterIndex,
                                ),
                              );
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class SpendingTrendChart extends StatefulWidget {
  final List<AppTransaction> expenses;
  final Currency currency;
  final int filterIndex;
  final DateTime? baseDate;
  final ValueChanged<DateTimeRange>? onPeriodSelected;

  const SpendingTrendChart({
    super.key,
    required this.expenses,
    required this.currency,
    required this.filterIndex,
    this.baseDate,
    this.onPeriodSelected,
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

    final amounts = _spendingTrendAmounts(
      widget.expenses,
      widget.filterIndex,
      widget.baseDate ?? DateTime.now(),
    );
    final dates = amounts.map((entry) => entry.key).toList();
    final peak = amounts.fold(
      0.0,
      (maximum, entry) => math.max(maximum, entry.value),
    );
    double maxY = peak * (widget.filterIndex == 0 ? 1.2 : 1.1);
    if (maxY == 0) maxY = 100;
    final bottomLabels = dates
        .map(
          (date) => widget.filterIndex == 0
              ? DateFormat('E').format(date).substring(0, 1)
              : DateFormat(widget.filterIndex == 2 ? 'MMM' : 'd').format(date),
        )
        .toList();
    final barGroups = [
      for (var i = 0; i < amounts.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: amounts[i].value,
              color: AppTheme.primaryColor(context),
              width: widget.filterIndex == 0
                  ? 16
                  : widget.filterIndex == 2
                  ? 12
                  : 4,
              // Small daily amounts must not be forced into rounded dots.
              borderRadius: widget.filterIndex == 0
                  ? BorderRadius.circular(6)
                  : widget.filterIndex == 2
                  ? BorderRadius.circular(4)
                  : const BorderRadius.vertical(top: Radius.circular(1)),
              backDrawRodData: BackgroundBarChartRodData(
                show: widget.filterIndex == 0,
                toY: maxY,
                color: AppTheme.dividerColor(context).withValues(alpha: .2),
              ),
            ),
          ],
        ),
    ];

    final rough = maxY / 4;
    final power = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final fraction = rough / power;
    final step = widget.filterIndex != 0
        ? (fraction >= 5
              ? 5
              : fraction >= 2
              ? 2
              : 1)
        : (fraction <= 1
              ? 1
              : fraction <= 2
              ? 2
              : fraction <= 5
              ? 5
              : 10);
    final interval = step * power;
    if (widget.filterIndex == 0) {
      maxY = (maxY / interval).ceil() * interval;
    }
    final total = amounts.fold(0.0, (sum, entry) => sum + entry.value);
    return Semantics(
      label:
          'Spending trend. Total ${widget.currency.formatter.format(total)}. ${widget.onPeriodSelected == null ? 'Touch a bar for its date and amount.' : 'Tap a bar to view its spending transactions. View amounts offers the same details as a list.'}',
      child: ExcludeSemantics(
        child: Container(
          height: 240,
          padding: const EdgeInsets.all(16),
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
                      if (widget.filterIndex == 1 &&
                          !{
                            1,
                            7,
                            14,
                            21,
                            bottomLabels.length,
                          }.contains(index + 1)) {
                        return const SizedBox.shrink();
                      }
                      if (widget.filterIndex == 2 && index.isOdd) {
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
                  final index = barTouchResponse?.spot?.touchedBarGroupIndex;
                  if (event is FlTapUpEvent &&
                      index != null &&
                      index >= 0 &&
                      index < dates.length) {
                    widget.onPeriodSelected?.call(
                      _spendingTrendRange(dates[index], widget.filterIndex),
                    );
                  }
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
                        if (widget.onPeriodSelected != null)
                          TextSpan(
                            text: '\nTap to view transactions',
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
  }
}
