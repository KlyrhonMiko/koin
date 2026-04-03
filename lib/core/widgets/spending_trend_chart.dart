import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/currency.dart';
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
  Widget build(BuildContext context) {
    if (widget.expenses.isEmpty) return const SizedBox.shrink();

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
      }
    } else {
      // Month
      for (int i = 0; i < sortedDaily.length; i++) {
        if (sortedDaily[i].value > maxY) maxY = sortedDaily[i].value;
      }
      maxY = maxY * 1.2;
      if (maxY == 0) maxY = 100;

      for (int i = 0; i < sortedDaily.length; i++) {
        var entry = sortedDaily[i];
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

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(widget.filterIndex),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutQuart,
        builder: (context, value, child) {
          return BarChart(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY / 4) == 0 ? 1 : maxY / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppTheme.dividerColor(
                      context,
                    ).withValues(alpha: 0.3),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
                    interval: (maxY / 4) == 0 ? 1 : maxY / 4,
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
                            fontSize: 10,
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

                  if (event is FlTapDownEvent || event is FlPanStartEvent) {
                    HapticService.light();
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.surfaceColor(context),
                  tooltipBorder: BorderSide(
                    color: AppTheme.dividerColor(
                      context,
                    ).withValues(alpha: 0.2),
                    width: 1,
                  ),
                  tooltipMargin: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    // Original toY is stored in the barGroups
                    final originalY =
                        barGroups[groupIndex].barRods[rodIndex].toY;
                    return BarTooltipItem(
                      '${bottomLabels[group.x.toInt()]}\n',
                      TextStyle(
                        color: AppTheme.textLightColor(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: NumberFormat.currency(
                            symbol: widget.currency.symbol,
                          ).format(originalY),
                          style: TextStyle(
                            color: AppTheme.textColor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
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
                      toY: rod.toY * value,
                      color: isTouched
                          ? AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.8)
                          : AppTheme.primaryColor(context),
                      width: isTouched ? rod.width + 2 : rod.width,
                      backDrawRodData: BackgroundBarChartRodData(
                        show: rod.backDrawRodData.show,
                        toY: rod.backDrawRodData.toY,
                        color: isTouched
                            ? AppTheme.dividerColor(
                                context,
                              ).withValues(alpha: 0.3)
                            : rod.backDrawRodData.color,
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
