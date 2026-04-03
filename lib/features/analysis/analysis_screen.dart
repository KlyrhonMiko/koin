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
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/widgets/animated_counter.dart';
import 'package:koin/core/widgets/spending_trend_chart.dart';
import 'dart:ui';
import 'dart:math' show pi;

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  late int _selectedFilterIndex;
  bool _isInitialized = false;
  int _touchedPieIndex = -1;
  bool _showPieChart = false;
  DateTime _baseDate = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      try {
        final settings = ref.read(settingsProvider);
        _selectedFilterIndex = settings.analysisFilterIndex;
        // Default to Month if "All" (3) was previously selected
        if (_selectedFilterIndex > 2) {
          _selectedFilterIndex = 1;
        }
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

            List<AppTransaction> filteredTransactions = transactions
                .where((t) => t.type == TransactionType.expense)
                .toList();

            double? previousExpense;

            if (_selectedFilterIndex == 0) {
              final startOfWeek = _baseDate.subtract(
                Duration(days: _baseDate.weekday - 1),
              );
              final startOfWeekDate = DateTime(
                startOfWeek.year,
                startOfWeek.month,
                startOfWeek.day,
              );
              final endOfWeekDate = startOfWeekDate.add(
                const Duration(days: 7),
              );

              final prevStartOfWeekDate = startOfWeekDate.subtract(
                const Duration(days: 7),
              );

              previousExpense = filteredTransactions
                  .where(
                    (t) =>
                        t.date.isAfter(
                          prevStartOfWeekDate.subtract(const Duration(days: 1)),
                        ) &&
                        t.date.isBefore(startOfWeekDate),
                  )
                  .fold<double>(0.0, (sum, t) => sum + t.amount);

              filteredTransactions = filteredTransactions
                  .where(
                    (t) =>
                        t.date.isAfter(
                          startOfWeekDate.subtract(const Duration(days: 1)),
                        ) &&
                        t.date.isBefore(endOfWeekDate),
                  )
                  .toList();
            } else if (_selectedFilterIndex == 1) {
              final prevMonthDate = DateTime(
                _baseDate.year,
                _baseDate.month - 1,
                1,
              );
              previousExpense = filteredTransactions
                  .where((t) {
                    return t.date.year == prevMonthDate.year &&
                        t.date.month == prevMonthDate.month;
                  })
                  .fold<double>(0.0, (sum, t) => sum + t.amount);

              filteredTransactions = filteredTransactions.where((t) {
                return t.date.year == _baseDate.year &&
                    t.date.month == _baseDate.month;
              }).toList();
            } else if (_selectedFilterIndex == 2) {
              final prevYear = _baseDate.year - 1;
              previousExpense = filteredTransactions
                  .where((t) {
                    return t.date.year == prevYear;
                  })
                  .fold<double>(0.0, (sum, t) => sum + t.amount);

              filteredTransactions = filteredTransactions.where((t) {
                return t.date.year == _baseDate.year;
              }).toList();
            }

            double totalExpense = filteredTransactions.fold(
              0,
              (sum, t) => sum + t.amount,
            );

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildImmersiveHeader(
                  context,
                  totalExpense,
                  previousExpense,
                  currency,
                ),
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
                        _buildChartSection(
                              context,
                              filteredTransactions,
                              categories,
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
    double? previousExpense,
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
                    AnimatedCounter(
                      value: totalExpense,
                      formatter: (val) => NumberFormat.currency(
                        symbol: currency.symbol,
                      ).format(val),
                      duration: const Duration(milliseconds: 1000),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ).animate().fade(delay: 150.ms).slideX(begin: -0.05),
                    const Gap(12),
                    Row(
                      children: [
                        _buildInlinePeriodSelector(),
                        if (previousExpense != null) ...[
                          const Gap(10),
                          _buildTrendBadge(
                            totalExpense,
                            previousExpense,
                          ).animate().fade(delay: 200.ms),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendBadge(double total, double previous) {
    if (previous == 0) return const SizedBox.shrink();

    final diff = total - previous;
    final percent = (diff / previous * 100).abs();
    final isIncrease = diff > 0;

    final badgeColor = isIncrease
        ? Colors.redAccent.shade100
        : Colors.greenAccent.shade200;
    final icon = isIncrease
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: badgeColor, size: 14),
          const Gap(4),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              shadows: [
                Shadow(color: badgeColor.withValues(alpha: 0.8), blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel() {
    if (_selectedFilterIndex == 0) {
      final startOfWeek = _baseDate.subtract(
        Duration(days: _baseDate.weekday - 1),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final startLabel = DateFormat('MMM d').format(startOfWeek);
      final endLabel = DateFormat('MMM d').format(endOfWeek);
      return '$startLabel - $endLabel';
    } else if (_selectedFilterIndex == 1) {
      return DateFormat('MMMM yyyy').format(_baseDate);
    } else if (_selectedFilterIndex == 2) {
      return DateFormat('yyyy').format(_baseDate);
    }
    return ''; // Should not happen with current filters
  }

  Widget _buildInlinePeriodSelector() {
    final now = DateTime.now();
    bool isCurrentPeriod = false;
    if (_selectedFilterIndex == 0) {
      final currentStart = now.subtract(Duration(days: now.weekday - 1));
      final baseStart = _baseDate.subtract(
        Duration(days: _baseDate.weekday - 1),
      );
      isCurrentPeriod =
          currentStart.year == baseStart.year &&
          currentStart.month == baseStart.month &&
          currentStart.day == baseStart.day;
    } else if (_selectedFilterIndex == 1) {
      isCurrentPeriod =
          now.year == _baseDate.year && now.month == _baseDate.month;
    } else if (_selectedFilterIndex == 2) {
      isCurrentPeriod = now.year == _baseDate.year;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            HapticService.selection();
            setState(() {
              if (_selectedFilterIndex == 0) {
                _baseDate = _baseDate.subtract(const Duration(days: 7));
              } else if (_selectedFilterIndex == 1) {
                _baseDate = DateTime(_baseDate.year, _baseDate.month - 1, 1);
              } else if (_selectedFilterIndex == 2) {
                _baseDate = DateTime(_baseDate.year - 1, _baseDate.month, 1);
              }
            });
          },
          child: const Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const Gap(6),
        Text(
          _getPeriodLabel(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const Gap(6),
        GestureDetector(
          onTap: isCurrentPeriod
              ? null
              : () {
                  HapticService.selection();
                  setState(() {
                    if (_selectedFilterIndex == 0) {
                      _baseDate = _baseDate.add(const Duration(days: 7));
                    } else if (_selectedFilterIndex == 1) {
                      _baseDate = DateTime(
                        _baseDate.year,
                        _baseDate.month + 1,
                        1,
                      );
                    } else if (_selectedFilterIndex == 2) {
                      _baseDate = DateTime(
                        _baseDate.year + 1,
                        _baseDate.month,
                        1,
                      );
                    }
                  });
                },
          child: Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: isCurrentPeriod ? 0.4 : 1.0),
            size: 18,
          ),
        ),
      ],
    ).animate().fade(delay: 150.ms);
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
          child: SizedBox(
            width: 156, // 52px per segment for better spacing
            height: 32,
            child: Stack(
              children: [
                // Sliding Indicator background
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart,
                  left: _selectedFilterIndex * (156 / 3.0),
                  top: 0,
                  bottom: 0,
                  width: 156 / 3.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Pill Options overlay
                Row(
                  children: [
                    _buildFilterOption(0, 'Wk'),
                    _buildFilterOption(1, 'Mo'),
                    _buildFilterOption(2, 'Yr'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService.selection();
          setState(() {
            _selectedFilterIndex = index;
            _baseDate = DateTime.now();
          });
          ref.read(settingsProvider.notifier).setAnalysisFilterIndex(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor(context) : Colors.white,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(
    BuildContext context,
    List<AppTransaction> expenses,
    List<TransactionCategory> categories,
    Currency currency,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _showPieChart ? 'Spending by Category' : 'Spending Trend',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.4,
              ),
            ),
            IconButton(
              onPressed: () {
                HapticService.selection();
                setState(() {
                  _showPieChart = !_showPieChart;
                });
              },
              icon: Icon(
                Icons.flip_rounded,
                color: AppTheme.primaryColor(context),
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor(
                  context,
                ).withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        const Gap(16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInBack,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, widget) {
                final isEntering = (widget?.key == ValueKey(_showPieChart));
                final rotation = isEntering
                    ? (1 - animation.value) * pi
                    : -(1 - animation.value) * pi;
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(rotation),
                  alignment: Alignment.center,
                  child: rotation.abs() <= (pi / 2 + 0.01)
                      ? widget
                      : const SizedBox.shrink(),
                );
              },
            );
          },
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: _showPieChart
              ? KeyedSubtree(
                  key: const ValueKey(true),
                  child: _buildCategoryPieChart(
                    context,
                    expenses,
                    categories,
                    currency,
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey(false),
                  child: SpendingTrendChart(
                    expenses: expenses,
                    currency: currency,
                    filterIndex: _selectedFilterIndex,
                    baseDate: _baseDate,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryPieChart(
    BuildContext context,
    List<AppTransaction> expenses,
    List<TransactionCategory> categories,
    Currency currency,
  ) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    Map<String, double> categorySpending = {};
    for (var tx in expenses) {
      categorySpending[tx.categoryId] =
          (categorySpending[tx.categoryId] ?? 0) + tx.amount;
    }

    var sortedEntries = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    double totalSpent = expenses.fold(0, (s, t) => s + t.amount);

    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
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
        key: ValueKey(_selectedFilterIndex), // Re-animate on filter change
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutQuart,
        builder: (context, value, child) {
          return Row(
            children: [
              Expanded(
                flex: 10,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    _touchedPieIndex = -1;
                                    return;
                                  }
                                  _touchedPieIndex = pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });

                                if (event is FlTapDownEvent ||
                                    event is FlPanStartEvent) {
                                  HapticService.light();
                                }
                              },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 4,
                        centerSpaceRadius: 46,
                        sections: sortedEntries.asMap().entries.map((entry) {
                          final index = entry.key;
                          final data = entry.value;
                          final isTouched = index == _touchedPieIndex;
                          final radius = isTouched ? 22.0 : 16.0;

                          final category = categories.firstWhere(
                            (c) => c.id == data.key,
                            orElse: () => TransactionCategory(
                              id: 'unknown',
                              name: 'Unknown',
                              iconCodePoint: Icons.help_outline.codePoint,
                              colorHex: '#9E9E9E',
                              type: TransactionType.expense,
                            ),
                          );

                          return PieChartSectionData(
                            color: category.color,
                            value: data.value * value,
                            title: '',
                            radius: radius * value,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                        const Gap(2),
                        Text(
                          NumberFormat.compactCurrency(
                            symbol: currency.symbol,
                          ).format(totalSpent * value),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor(context),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Expanded(
                flex: 12,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: sortedEntries.take(4).map((data) {
                    final index = sortedEntries.indexOf(data);
                    final isTouched =
                        _touchedPieIndex == -1 || _touchedPieIndex == index;
                    final opacity = isTouched ? 1.0 : 0.4;
                    final percent = (data.value / totalSpent) * 100;

                    final category = categories.firstWhere(
                      (c) => c.id == data.key,
                      orElse: () => TransactionCategory(
                        id: 'unknown',
                        name: 'Unknown',
                        iconCodePoint: Icons.help_outline.codePoint,
                        colorHex: '#9E9E9E',
                        type: TransactionType.expense,
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: opacity),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isTouched
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: AppTheme.textColor(
                                      context,
                                    ).withValues(alpha: opacity),
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  NumberFormat.compactCurrency(
                                    symbol: currency.symbol,
                                  ).format(data.value),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textLightColor(
                                      context,
                                    ).withValues(alpha: opacity),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${percent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor(
                                context,
                              ).withValues(alpha: opacity),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
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

        return PressableScale(
          onTap: () {
            // Future: Navigate to category detail analysis
            HapticService.light();
          },
          child: Container(
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const Gap(6),
                              Text(
                                '${percent.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.textLightColor(context),
                                ),
                              ),
                            ],
                          ),
                          AnimatedCounter(
                            value: entry.value,
                            formatter: (val) => NumberFormat.compactCurrency(
                              symbol: currency.symbol,
                            ).format(val),
                            duration: const Duration(milliseconds: 1000),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.5,
                            ),
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
