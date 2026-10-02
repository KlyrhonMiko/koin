import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
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

            final period = AnalysisPeriod.fromIndex(_selectedFilterIndex);
            final analysis = SpendingAnalysis.calculate(
              transactions: transactions,
              baseDate: _baseDate,
              period: period,
            );
            final filteredTransactions = analysis.filteredTransactions;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildImmersiveHeader(context, analysis, currency),
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
                    padding: const EdgeInsets.fromLTRB(
                      KoinSpacing.screenInset,
                      0,
                      KoinSpacing.screenInset,
                      100,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                              _buildChartSection(
                                context,
                                analysis,
                                categories,
                                currency,
                              ),
                              const Gap(32),
                              Row(
                                children: [
                                  Text(
                                    'Top Categories',
                                    style: TextStyle(
                                      fontSize: KoinTypography.sectionTitle,
                                      fontWeight: KoinTypography.headingWeight,
                                      color: AppTheme.textColor(context),
                                      letterSpacing:
                                          KoinTypography.headingTracking,
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(16),
                              _buildTopCategoriesList(
                                context,
                                ref,
                                analysis,
                                categories,
                                currency,
                              ),
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
                              ),
                              const Gap(64),
                            ]
                            .animate(interval: 40.ms)
                            .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                            .scale(
                              begin: const Offset(0.95, 0.95),
                              duration: 250.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ),
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
    SpendingAnalysis analysis,
    Currency currency,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        KoinSpacing.screenInset,
        16,
        KoinSpacing.screenInset,
        16,
      ),
      sliver: SliverToBoxAdapter(
        child: KoinSummaryCard(
          shapeStyle: SummaryShapeStyle.analysis,
          padding: const EdgeInsets.all(KoinSpacing.summaryInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Total Spent',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: KoinTypography.caption,
                              fontWeight: KoinTypography.labelWeight,
                              letterSpacing: 0.5,
                            ),
                          ),
                          _buildGlassFilterControl(context),
                        ],
                      ),
                      const Gap(12),
                      AnimatedCounter(
                        value: analysis.totalExpense,
                        formatter: (val) => NumberFormat.currency(
                          symbol: currency.symbol,
                        ).format(val),
                        duration: const Duration(milliseconds: 1000),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: KoinTypography.summaryAmount,
                          fontWeight: KoinTypography.headingWeight,
                          letterSpacing: KoinTypography.amountTracking,
                          height: KoinTypography.amountHeight,
                        ),
                      ),
                      const Gap(12),
                      SizedBox(
                        height: 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildInlinePeriodSelector(),
                            if (analysis.previousExpense != null) ...[
                              const Gap(10),
                              _buildTrendBadge(analysis),
                            ],
                          ],
                        ),
                      ),
                      const Gap(24),
                      _buildIntegratedForecast(context, currency),
                    ]
                    .animate(interval: 40.ms)
                    .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      duration: 250.ms,
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendBadge(SpendingAnalysis analysis) {
    if (analysis.previousExpense == null || analysis.previousExpense == 0) {
      return const SizedBox.shrink();
    }

    final badgeColor = analysis.isIncrease
        ? Colors.redAccent.shade100
        : Colors.greenAccent.shade200;
    final icon = analysis.isIncrease
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: badgeColor, size: 14),
        const Gap(4),
        Text(
          '${analysis.trendPercentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: KoinTypography.caption,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [
              Shadow(color: badgeColor.withValues(alpha: 0.8), blurRadius: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntegratedForecast(BuildContext context, Currency currency) {
    final forecastAsync = ref.watch(forecastProvider(_selectedFilterIndex));

    Widget buildRow({
      required String inflowStr,
      required String outflowStr,
      required String netStr,
      bool isWarning = false,
    }) {
      return Column(
        children: [
          Container(
            height: 1,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const Gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inflow',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: KoinTypography.small,
                        fontWeight: KoinTypography.supportingWeight,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      inflowStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: KoinTypography.body,
                        fontWeight: KoinTypography.titleWeight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Outflow',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: KoinTypography.small,
                        fontWeight: KoinTypography.supportingWeight,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      outflowStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: KoinTypography.body,
                        fontWeight: KoinTypography.titleWeight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isWarning) ...[
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent.shade100,
                            size: 14,
                          ),
                          const Gap(4),
                        ],
                        Text(
                          'Net Balance',
                          style: TextStyle(
                            color: isWarning
                                ? Colors.redAccent.shade100
                                : Colors.white.withValues(alpha: 0.7),
                            fontSize: KoinTypography.small,
                            fontWeight: KoinTypography.supportingWeight,
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      netStr,
                      style: TextStyle(
                        color: isWarning
                            ? Colors.redAccent.shade100
                            : Colors.white,
                        fontSize: KoinTypography.body,
                        fontWeight: KoinTypography.headingWeight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: forecastAsync.when(
        data: (forecast) {
          if (forecast.forecastedInflow == 0 &&
              forecast.forecastedOutflow == 0) {
            return const SizedBox.shrink();
          }
          return buildRow(
            inflowStr: NumberFormat.currency(
              symbol: currency.symbol,
            ).format(forecast.forecastedInflow),
            outflowStr: NumberFormat.currency(
              symbol: currency.symbol,
            ).format(forecast.forecastedOutflow),
            netStr: NumberFormat.currency(
              symbol: currency.symbol,
            ).format(forecast.predictedNetBalance),
            isWarning: forecast.isWarning,
          );
        },
        loading: () =>
            buildRow(inflowStr: '...', outflowStr: '...', netStr: '...'),
        error: (e, st) => const SizedBox.shrink(),
      ),
    );
  }

  AnalysisPeriod get _currentPeriod =>
      AnalysisPeriod.fromIndex(_selectedFilterIndex);

  String _getPeriodLabel() => _currentPeriod.formatPeriod(_baseDate);

  Widget _buildInlinePeriodSelector() {
    final period = _currentPeriod;
    final isCurrentPeriod = period.isCurrentPeriod(_baseDate);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            HapticService.selection();
            setState(() {
              _baseDate = period.previousPeriod(_baseDate);
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
            fontSize: KoinTypography.caption,
            fontWeight: KoinTypography.titleWeight,
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
                    _baseDate = period.nextPeriod(_baseDate);
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
              fontWeight: isSelected
                  ? KoinTypography.headingWeight
                  : KoinTypography.labelWeight,
              fontSize: KoinTypography.caption,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(
    BuildContext context,
    SpendingAnalysis analysis,
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
                fontSize: KoinTypography.sectionTitle,
                fontWeight: KoinTypography.headingWeight,
                color: AppTheme.textColor(context),
                letterSpacing: KoinTypography.headingTracking,
              ),
            ),
            IconButton(
              onPressed: () {
                HapticService.selection();
                setState(() {
                  _showPieChart = !_showPieChart;
                });
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInBack,
                transitionBuilder: _buildFlipTransition,
                child: Transform.scale(
                  key: ValueKey(_showPieChart),
                  scaleX: _showPieChart ? -1 : 1,
                  child: Icon(
                    Icons.flip_rounded,
                    color: AppTheme.primaryColor(context),
                  ),
                ),
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
          transitionBuilder: _buildFlipTransition,
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[...previousChildren, ?currentChild],
            );
          },
          child: _showPieChart
              ? KeyedSubtree(
                  key: const ValueKey(true),
                  child: _buildCategoryPieChart(
                    context,
                    analysis,
                    categories,
                    currency,
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey(false),
                  child: SpendingTrendChart(
                    expenses: analysis.filteredTransactions,
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
    SpendingAnalysis analysis,
    List<TransactionCategory> categories,
    Currency currency,
  ) {
    if (analysis.categoryBreakdown.isEmpty) return const SizedBox.shrink();

    final breakdown = analysis.categoryBreakdown;
    final totalSpent = analysis.totalExpense;

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
                        sections: breakdown.asMap().entries.map((entry) {
                          final index = entry.key;
                          final data = entry.value;
                          final isTouched = index == _touchedPieIndex;
                          final radius = isTouched ? 22.0 : 16.0;

                          final category = categories.firstWhere(
                            (c) => c.id == data.categoryId,
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
                            value: data.amount * value,
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
                            fontSize: KoinTypography.overline,
                            fontWeight: KoinTypography.labelWeight,
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                        const Gap(2),
                        Text(
                          NumberFormat.compactCurrency(
                            symbol: currency.symbol,
                          ).format(totalSpent * value),
                          style: TextStyle(
                            fontSize: KoinTypography.itemTitle,
                            fontWeight: KoinTypography.headingWeight,
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
                  children: breakdown.take(4).map((data) {
                    final index = breakdown.indexOf(data);
                    final isTouched =
                        _touchedPieIndex == -1 || _touchedPieIndex == index;
                    final opacity = isTouched ? 1.0 : 0.4;
                    final percent = data.percentage;

                    final category = categories.firstWhere(
                      (c) => c.id == data.categoryId,
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
                                    fontSize: KoinTypography.small,
                                    fontWeight: isTouched
                                        ? KoinTypography.titleWeight
                                        : KoinTypography.supportingWeight,
                                    color: AppTheme.textColor(
                                      context,
                                    ).withValues(alpha: opacity),
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  NumberFormat.compactCurrency(
                                    symbol: currency.symbol,
                                  ).format(data.amount),
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
                              fontSize: KoinTypography.small,
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
    WidgetRef ref,
    SpendingAnalysis analysis,
    List<TransactionCategory> categories,
    Currency currency,
  ) {
    if (analysis.categoryBreakdown.isEmpty) return const SizedBox.shrink();

    return Column(
      children: analysis.categoryBreakdown.map((item) {
        final category = categories.firstWhere(
          (c) => c.id == item.categoryId,
          orElse: () => TransactionCategory(
            id: 'unknown',
            name: 'Unknown',
            iconCodePoint: Icons.help_outline.codePoint,
            colorHex: '#9E9E9E',
            type: TransactionType.expense,
          ),
        );
        final percent = item.percentage;

        return PressableScale(
          onTap: () {
            HapticService.light();
            ref
                .read(transactionFilterProvider.notifier)
                .updateFilter(
                  TransactionFilter(
                    categoryIds: {category.id},
                    dateRange: analysis.currentDateRange,
                  ),
                );
            ref.read(activityTabProvider.notifier).setIndex(1);
            ref.read(navigationProvider.notifier).setIndex(1);
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
                                  fontWeight: KoinTypography.titleWeight,
                                  fontSize: KoinTypography.itemTitle,
                                ),
                              ),
                              const Gap(6),
                              Text(
                                '${percent.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: KoinTypography.labelWeight,
                                  fontSize: KoinTypography.small,
                                  color: AppTheme.textLightColor(context),
                                ),
                              ),
                            ],
                          ),
                          AnimatedCounter(
                            value: item.amount,
                            formatter: (val) => NumberFormat.compactCurrency(
                              symbol: currency.symbol,
                            ).format(val),
                            duration: const Duration(milliseconds: 1000),
                            style: const TextStyle(
                              fontWeight: KoinTypography.headingWeight,
                              fontSize: KoinTypography.itemTitle,
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
                fontSize: KoinTypography.sectionTitle,
                fontWeight: KoinTypography.headingWeight,
                letterSpacing: KoinTypography.headingTracking,
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
                fontSize: KoinTypography.compact,
              ),
              textAlign: TextAlign.center,
            )
            .animate()
            .slideY(begin: 0.2, delay: 400.ms, duration: 400.ms)
            .fadeIn(),
      ],
    );
  }

  Widget _buildFlipTransition(Widget child, Animation<double> animation) {
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
  }
}
