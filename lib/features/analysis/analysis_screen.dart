import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/currency.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'dart:ui';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  late int _selectedFilterIndex;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      try {
        final settings = ref.read(settingsProvider);
        _selectedFilterIndex = settings.analysisFilterIndex;
      } catch (e) {
        debugPrint('Error loading analysis filter setting: $e');
        _selectedFilterIndex = 0;
      }
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? [];
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: RefreshIndicator(
        onRefresh: () {
          HapticService.light();
          return ref.read(transactionProvider.notifier).loadTransactions();
        },
        color: AppTheme.primaryColor(context),
        backgroundColor: AppTheme.surfaceColor(context),
        child: transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return _buildEmptyState(
                context,
                'No expense data yet',
                'Add some expenses to see your analysis',
                Icons.insights_rounded,
              );
            }

            final now = DateTime.now();
            List<AppTransaction> filteredTransactions = transactions
                .where((t) => t.type == TransactionType.expense)
                .toList();

            if (_selectedFilterIndex == 0) {
              final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
              final startOfWeekDate = DateTime(
                startOfWeek.year,
                startOfWeek.month,
                startOfWeek.day,
              );
              filteredTransactions = filteredTransactions
                  .where(
                    (t) => t.date.isAfter(
                      startOfWeekDate.subtract(const Duration(days: 1)),
                    ),
                  )
                  .toList();
            } else if (_selectedFilterIndex == 1) {
              filteredTransactions = filteredTransactions.where((t) {
                return t.date.year == now.year && t.date.month == now.month;
              }).toList();
            }

            double totalExpense = filteredTransactions.fold(
              0,
              (sum, t) => sum + t.amount,
            );

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildImmersiveHeader(context, totalExpense, currency),
                if (filteredTransactions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: const Alignment(0, -0.3),
                      child: _buildEmptyStateContent(
                        context,
                        'No expenses found',
                        'Try changing the time period',
                        Icons.search_off_rounded,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildTrendChart(
                              context,
                              filteredTransactions,
                              currency,
                            )
                            .animate()
                            .fade(duration: 600.ms, delay: 100.ms)
                            .slideY(begin: 0.1),
                        const Gap(32),
                        Row(
                          children: [
                            Text(
                              'Top Categories',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textColor(context),
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ).animate().fade(delay: 200.ms),
                        const Gap(16),
                        _buildTopCategoriesList(
                          context,
                          filteredTransactions,
                          categories,
                          currency,
                        ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
                        const Gap(32),
                        Center(
                          child: Container(
                            width: 48,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.dividerColor(
                                context,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ).animate().fade(delay: 400.ms),
                        const Gap(64),
                      ]),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildImmersiveHeader(
    BuildContext context,
    double totalExpense,
    Currency currency,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      sliver: SliverToBoxAdapter(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient(context),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Total Spent',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ).animate().fade(delay: 100.ms),
                        _buildGlassFilterControl(context),
                      ],
                    ),
                    const Gap(12),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: totalExpense),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCirc,
                      builder: (context, value, child) {
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            NumberFormat.currency(
                              symbol: currency.symbol,
                            ).format(value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              height: 1.1,
                            ),
                          ),
                        );
                      },
                    ).animate().fade(delay: 150.ms).slideX(begin: -0.05),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassFilterControl(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption(0, 'Wk'),
              _buildFilterOption(1, 'Mo'),
              _buildFilterOption(2, 'All'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() => _selectedFilterIndex = index);
        ref.read(settingsProvider.notifier).setAnalysisFilterIndex(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor(context) : Colors.white,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    List<AppTransaction> expenses,
    Currency currency,
  ) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    Map<String, double> dailyTotals = {};
    for (var tx in expenses) {
      String dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + tx.amount;
    }

    var sortedDaily =
        dailyTotals.entries
            .map((e) => MapEntry(DateTime.parse(e.key), e.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    DateTime endDate = DateTime.now();

    List<BarChartGroupData> barGroups = [];
    List<String> bottomLabels = [];
    double maxY = 0;

    if (_selectedFilterIndex == 0) {
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
    } else {
      // Month or All Time
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
                width: _selectedFilterIndex == 1 ? 8 : 4,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
        bottomLabels.add(
          DateFormat(
            _selectedFilterIndex == 1 ? 'd' : 'MMM d',
          ).format(entry.key),
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
        key: ValueKey(_selectedFilterIndex),
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
                      if (_selectedFilterIndex != 0 &&
                          index % 2 != 0 &&
                          bottomLabels.length > 7) {
                        return const SizedBox.shrink();
                      }
                      if (_selectedFilterIndex == 2 &&
                          index % 5 != 0 &&
                          bottomLabels.length > 15) {
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
                  if (event is FlTapDownEvent || event is FlPanStartEvent) {
                    HapticService.light();
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.textColor(context),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    // Original toY is stored in the barGroups
                    final originalY =
                        barGroups[groupIndex].barRods[rodIndex].toY;
                    return BarTooltipItem(
                      '${bottomLabels[group.x.toInt()]}\n',
                      const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: NumberFormat.currency(
                            symbol: currency.symbol,
                          ).format(originalY),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: barGroups.map((group) {
                return BarChartGroupData(
                  x: group.x,
                  barRods: group.barRods.map((rod) {
                    return rod.copyWith(toY: rod.toY * value);
                  }).toList(),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopCategoriesList(
    BuildContext context,
    List<AppTransaction> expenses,
    List<TransactionCategory> categories,
    Currency currency,
  ) {
    Map<String, double> categorySpending = {};
    for (var tx in expenses) {
      categorySpending[tx.categoryId] =
          (categorySpending[tx.categoryId] ?? 0) + tx.amount;
    }

    if (categorySpending.isEmpty) return const SizedBox.shrink();

    var sortedEntries = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    double totalSpent = expenses.fold(0, (s, t) => s + t.amount);

    return Column(
      children: sortedEntries.map((entry) {
        final category = categories.firstWhere(
          (c) => c.id == entry.key,
          orElse: () => TransactionCategory(
            id: 'unknown',
            name: 'Unknown',
            iconCodePoint: Icons.help_outline.codePoint,
            colorHex: '#9E9E9E',
            type: TransactionType.expense,
          ),
        );
        final percent = (entry.value / totalSpent) * 100;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconUtils.getIcon(category.iconCodePoint),
                  color: category.color,
                  size: 24,
                ),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: entry.value),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCirc,
                          builder: (context, value, child) {
                            return Text(
                              NumberFormat.compactCurrency(
                                symbol: currency.symbol,
                              ).format(value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Gap(8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 6,
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor(
                            context,
                          ).withValues(alpha: 0.3),
                        ),
                        child:
                            FractionallySizedBox(
                              widthFactor: percent / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: category.color,
                                ),
                              ),
                            ).animate().scaleX(
                              alignment: Alignment.centerLeft,
                              duration: 800.ms,
                              curve: Curves.easeOutCirc,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: const Alignment(0, -0.3),
            child: _buildEmptyStateContent(context, title, subtitle, icon),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateContent(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 56,
                color: AppTheme.primaryColor(context).withValues(alpha: 0.6),
              ),
            )
            .animate()
            .scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 600.ms)
            .fadeIn(),
        const SizedBox(height: 24),
        Text(
              title,
              style: TextStyle(
                color: AppTheme.textColor(context),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            )
            .animate()
            .slideY(begin: 0.2, delay: 300.ms, duration: 400.ms)
            .fadeIn(),
        const SizedBox(height: 8),
        Text(
              subtitle,
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            )
            .animate()
            .slideY(begin: 0.2, delay: 400.ms, duration: 400.ms)
            .fadeIn(),
      ],
    );
  }
}
