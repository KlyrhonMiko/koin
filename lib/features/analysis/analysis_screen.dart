import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:intl/intl.dart';

import 'widgets/forecast_summary.dart';

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
      _baseDate = ref.read(calendarDayProvider);
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(calendarDayProvider, (previous, next) {
      if (previous != null &&
          _currentPeriod.isCurrentPeriod(_baseDate, previous)) {
        setState(() => _baseDate = next);
      }
    });
    ref.watch(calendarDayProvider);
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildForecast(context, currency),
                  ),
                ),
                if (filteredTransactions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.center,
                      child: _buildEmptyStateContent(
                        context,
                        'No expenses found',
                        'Try changing the time period',
                        KoinIcons.magnifyingGlassMinus,
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
                            ]
                            .koinAnimate(
                              context,
                              autoPlay: !MediaQuery.disableAnimationsOf(
                                context,
                              ),
                              onInit: KoinMotion.onInit(context),
                              interval: KoinMotion.duration(context, 40.ms),
                            )
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
          error: (_, _) => KoinErrorState(
            onRetry: () => ref.invalidate(transactionProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildImmersiveHeader(
    BuildContext context,
    SpendingAnalysis analysis,
    Currency currency,
  ) {
    final hideAmount = ref.watch(settingsProvider.select((s) => s.hideBalance));
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        KoinSpacing.screenInset,
        0,
        KoinSpacing.screenInset,
        16,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KoinSummaryCard(
              shapeStyle: SummaryShapeStyle.analysis,
              padding: const EdgeInsets.all(24),
              topRightAction: KoinVisibilityButton(
                hidden: hideAmount,
                subject: 'spending',
                onPressed: () => ref
                    .read(settingsProvider.notifier)
                    .setHideBalance(!hideAmount),
              ),
              child: KoinSummaryContent(
                label: 'Total Spent',
                currencyCode: currency.code,
                amount: SizedBox(
                  width: double.infinity,
                  child: hideAmount
                      ? const SizedBox(
                          height: 42,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '****',
                              semanticsLabel: 'Spending hidden',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: KoinTypography.supportingWeight,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedCounter(
                            value: analysis.totalExpense,
                            formatter: currency.formatter.format,
                            duration: const Duration(milliseconds: 1000),
                            style: KoinTypography.summaryAmountStyle,
                          ),
                        ),
                ),
                footer:
                    analysis.previousExpense == null ||
                        analysis.previousExpense == 0
                    ? null
                    : hideAmount
                    ? const Text(
                        'Spending comparison hidden',
                        style: KoinTypography.summaryLabelStyle,
                      )
                    : _buildTrendBadge(analysis),
              ),
            ),
            const Gap(12),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context);
                final controlHeight =
                    (textScale.scale(KoinTypography.caption) + 24).clamp(
                      48.0,
                      double.infinity,
                    );
                final stacked =
                    constraints.maxWidth < 330 || textScale.scale(13) > 18;
                final dateControl = SizedBox(
                  key: const ValueKey('analysis_date_selector'),
                  height: controlHeight,
                  child: _buildInlinePeriodSelector(),
                );
                final selector = SizedBox(
                  key: const ValueKey('analysis_period_selector'),
                  width: stacked
                      ? constraints.maxWidth
                      : (152 * textScale.scale(13) / 13).clamp(
                          152.0,
                          constraints.maxWidth,
                        ),
                  height: controlHeight,
                  child: _buildDetachedFilterControl(context),
                );
                final Widget controls;
                if (stacked) {
                  controls = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [selector, dateControl],
                  );
                } else {
                  controls = Row(
                    children: [
                      Expanded(child: dateControl),
                      Container(
                        width: 1,
                        height: 20,
                        color: AppTheme.dividerColor(context),
                      ),
                      const Gap(4),
                      selector,
                    ],
                  );
                }
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.dividerColor(context)),
                  ),
                  child: controls,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendBadge(SpendingAnalysis analysis) {
    if (analysis.previousExpense == null || analysis.previousExpense == 0) {
      return const SizedBox.shrink();
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${analysis.trendPercentage.toStringAsFixed(1)}% ',
            style: const TextStyle(fontWeight: KoinTypography.titleWeight),
          ),
          TextSpan(
            text:
                '${analysis.isIncrease ? 'more' : 'less'} than previous ${['week', 'month', 'year'][_selectedFilterIndex]}',
          ),
        ],
      ),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: KoinTypography.small,
        fontWeight: KoinTypography.labelWeight,
        height: 1.4,
      ),
    );
  }

  Widget _buildForecast(BuildContext context, Currency currency) {
    final forecastAsync = ref.watch(forecastProvider(_selectedFilterIndex));
    return forecastAsync.when(
      data: (forecast) => ForecastSummary(
        forecast: forecast,
        currency: currency,
        horizon: ForecastHorizon.fromIndex(_selectedFilterIndex),
        hideAmounts: ref.watch(settingsProvider).hideBalance,
      ),
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forecast',
              style: TextStyle(
                color: AppTheme.textColor(context),
                fontSize: KoinTypography.sectionTitle,
                fontWeight: KoinTypography.headingWeight,
              ),
            ),
            const Gap(8),
            Text(
              'Estimating balance...',
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontSize: KoinTypography.caption,
              ),
            ),
          ],
        ),
      ),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(forecastProvider(_selectedFilterIndex)),
        child: Text(
          'Could not estimate balance. Retry',
          style: TextStyle(color: AppTheme.textColor(context)),
        ),
      ),
    );
  }

  AnalysisPeriod get _currentPeriod =>
      AnalysisPeriod.fromIndex(_selectedFilterIndex);

  String _getPeriodLabel() {
    if (_currentPeriod != AnalysisPeriod.week) {
      return _currentPeriod.formatPeriod(_baseDate);
    }
    final range = _currentPeriod.dateRange(_baseDate);
    if (range.start.year != range.end.year) {
      final format = DateFormat('MMM d, yy');
      return '${format.format(range.start)}–${format.format(range.end)}';
    }
    final start = DateFormat('MMM d').format(range.start);
    final end = range.start.month == range.end.month
        ? '${range.end.day}'
        : DateFormat('MMM d').format(range.end);
    return '$start–$end';
  }

  Widget _buildInlinePeriodSelector() {
    final period = _currentPeriod;
    final isCurrentPeriod = period.isCurrentPeriod(
      _baseDate,
      ref.read(calendarDayProvider),
    );

    return KoinPeriodNavigation(
          label: _getPeriodLabel(),
          onPrevious: () {
            HapticService.selection();
            setState(() {
              _baseDate = period.previousPeriod(_baseDate);
            });
          },
          onNext: isCurrentPeriod
              ? null
              : () {
                  HapticService.selection();
                  setState(() {
                    _baseDate = period.nextPeriod(_baseDate);
                  });
                },
          previousTooltip:
              'Previous ${['week', 'month', 'year'][_selectedFilterIndex]}',
          nextTooltip:
              'Next ${['week', 'month', 'year'][_selectedFilterIndex]}',
        )
        .koinAnimate(
          context,
          autoPlay: !MediaQuery.disableAnimationsOf(context),
          onInit: KoinMotion.onInit(context),
        )
        .fade(delay: 150.ms);
  }

  Widget _buildDetachedFilterControl(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 3;
          return Stack(
            children: [
              // Sliding Indicator background
              AnimatedPositioned(
                duration: KoinMotion.duration(context, 300.ms),
                curve: Curves.easeOutQuart,
                left: _selectedFilterIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      AppTheme.boxShadow(
                        context,
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
          );
        },
      ),
    );
  }

  Widget _buildFilterOption(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: ['Week', 'Month', 'Year'][index],
        child: GestureDetector(
          onTap: () {
            HapticService.selection();
            setState(() {
              _selectedFilterIndex = index;
              _baseDate = ref.read(calendarDayProvider);
            });
            ref.read(settingsProvider.notifier).setAnalysisFilterIndex(index);
          },
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.contentColor(
                        context,
                        AppTheme.primaryColor(context),
                        background: Colors.white,
                      )
                    : AppTheme.textColor(context),
                fontWeight: isSelected
                    ? KoinTypography.headingWeight
                    : KoinTypography.labelWeight,
                fontSize: KoinTypography.caption,
              ),
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
            Expanded(
              child: Text(
                _showPieChart ? 'Spending by Category' : 'Spending Trend',
                style: TextStyle(
                  fontSize: KoinTypography.sectionTitle,
                  fontWeight: KoinTypography.headingWeight,
                  color: AppTheme.textColor(context),
                  letterSpacing: KoinTypography.headingTracking,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                HapticService.selection();
                setState(() {
                  _showPieChart = !_showPieChart;
                  _touchedPieIndex = -1;
                });
              },
              icon: Icon(
                _showPieChart
                    ? KoinIcons.chartBar
                    : KoinIcons.chartDonut,
                size: 18,
              ),
              label: Text(_showPieChart ? 'Trend' : 'Categories'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textLightColor(context),
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
        const Gap(8),
        // The surface stays opaque while only the graph content fades through.
        // No rotation or scale: category proportions and totals stay readable.
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(32),
          ),
          child: AnimatedSwitcher(
            key: const ValueKey('spending-chart-switcher'),
            duration: KoinMotion.duration(
              context,
              const Duration(milliseconds: 240),
            ),
            switchInCurve: const Interval(
              0.35,
              1,
              curve: Cubic(0.23, 1, 0.32, 1),
            ),
            switchOutCurve: const Interval(0.6, 1),
            transitionBuilder: (child, animation) {
              final outgoing = child.key != ValueKey(_showPieChart);
              return IgnorePointer(
                ignoring: outgoing,
                child: ExcludeSemantics(
                  excluding: outgoing,
                  child: FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (previousChildren.isNotEmpty) previousChildren.last,
                      ?currentChild,
                    ],
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
    // Keep every slice represented in the legend, including the long tail.
    final visible = breakdown.length > 4 ? breakdown.take(3) : breakdown;
    final slices = visible.map((item) {
      final category = categories
          .where((c) => c.id == item.categoryId)
          .firstOrNull;
      return (
        name: category?.name ?? 'Uncategorized',
        amount: item.amount,
        color: category?.color ?? AppTheme.textLightColor(context),
      );
    }).toList();
    if (breakdown.length > 4) {
      slices.add((
        name: 'Other',
        amount: breakdown
            .skip(3)
            .fold<double>(0, (sum, item) => sum + item.amount),
        color: AppTheme.textLightColor(context),
      ));
    }
    final selected = _touchedPieIndex >= 0 && _touchedPieIndex < slices.length
        ? _touchedPieIndex
        : -1;
    final label = selected < 0 ? 'Total' : slices[selected].name;
    final amount = selected < 0 ? totalSpent : slices[selected].amount;
    final text = AppTheme.textColor(context);
    final muted = AppTheme.textLightColor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the same footprint as Trend at every category count.
        final chartSize = ((constraints.maxWidth - 32) * 0.43).clamp(
          110.0,
          160.0,
        );
        const thickness = 18.0;
        final hole = chartSize / 2 - thickness - 2;
        final donut = SizedBox(
          key: const ValueKey('category-donut'),
          width: chartSize,
          height: chartSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Semantics(
                label: slices
                    .map(
                      (s) =>
                          '${s.name}: ${currency.formatter.format(s.amount)}',
                    )
                    .join('; '),
                child: PieChart(
                  duration: KoinMotion.duration(
                    context,
                    const Duration(milliseconds: 180),
                  ),
                  curve: const Cubic(0.23, 1, 0.32, 1),
                  PieChartData(
                    startDegreeOffset: -90,
                    centerSpaceRadius: hole,
                    sectionsSpace: slices.length == 1 ? 0 : 2,
                    borderData: FlBorderData(show: false),
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent &&
                            event is! FlPanUpdateEvent) {
                          return;
                        }
                        final index =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        if (index < 0 || index >= slices.length) return;
                        final next = event is FlTapUpEvent && selected == index
                            ? -1
                            : index;
                        if (next == _touchedPieIndex) return;
                        HapticService.selection();
                        setState(() => _touchedPieIndex = next);
                      },
                    ),
                    sections: List.generate(
                      slices.length,
                      (i) => PieChartSectionData(
                        value: slices[i].amount,
                        color: selected < 0 || selected == i
                            ? slices[i].color
                            : slices[i].color.withValues(alpha: 0.3),
                        radius: thickness,
                        showTitle: false,
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: SizedBox(
                  width: hole * 1.7,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: KoinTypography.chartLabel,
                          fontWeight: KoinTypography.labelWeight,
                        ),
                      ),
                      const Gap(4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currency.compactFormatter.format(amount),
                          style: TextStyle(
                            color: text,
                            fontSize: KoinTypography.cardAmount,
                            fontWeight: KoinTypography.headingWeight,
                            letterSpacing: KoinTypography.headingTracking,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        final legend = Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(slices.length, (i) {
            final slice = slices[i];
            final percentage = totalSpent <= 0
                ? 0.0
                : slice.amount / totalSpent * 100;
            final percentText = percentage > 0 && percentage < 1
                ? '<1%'
                : '${percentage.toStringAsFixed(0)}%';
            return Semantics(
              selected: selected == i,
              child: Tooltip(
                message:
                    '${slice.name}: ${currency.formatter.format(slice.amount)} ($percentText)',
                child: InkWell(
                  key: ValueKey('category-legend-$i'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticService.selection();
                    setState(() => _touchedPieIndex = selected == i ? -1 : i);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: slice.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        slice.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: text,
                                          fontSize: KoinTypography.small,
                                          fontWeight:
                                              KoinTypography.titleWeight,
                                        ),
                                      ),
                                    ),
                                    const Gap(8),
                                    Text(
                                      percentText,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: KoinTypography.chartLabel,
                                        fontWeight: KoinTypography.labelWeight,
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(3),
                                Text(
                                  currency.compactFormatter.format(
                                    slice.amount,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: text,
                                    fontSize: KoinTypography.small,
                                    fontWeight: KoinTypography.titleWeight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
        return Container(
          key: const ValueKey('category-chart-card'),
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
          child: Row(
            children: [
              donut,
              const Gap(16),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('category-legend-scroll'),
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  child: legend,
                ),
              ),
            ],
          ),
        );
      },
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
      children: analysis.categoryBreakdown.asMap().entries.map((entry) {
        final item = entry.value;
        final category = categories.firstWhere(
          (c) => c.id == item.categoryId,
          orElse: () => TransactionCategory(
            id: 'unknown',
            name: 'Uncategorized',
            iconCodePoint: KoinIcons.question.codePoint,
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
                    categoryIds: {item.categoryId},
                    dateRange: analysis.currentDateRange,
                  ),
                );
            ref.read(activityTabProvider.notifier).setIndex(1);
            ref.read(navigationProvider.notifier).setIndex(1);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: entry.key == 0
                  ? null
                  : Border(
                      top: BorderSide(
                        color: AppTheme.dividerColor(context)
                            .withValues(alpha: 0.35),
                      ),
                    ),
            ),
            child: Row(
              children: [
                KoinIconBadge(
                  icon: IconUtils.getIcon(category.iconCodePoint),
                  color: category.color,
                  radius: 12,
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Flexible(
                                  child: Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontWeight: KoinTypography.titleWeight,
                                      fontSize: KoinTypography.body,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Gap(6),
                                Text(
                                  percent > 0 && percent < 1
                                      ? '<1%'
                                      : '${percent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: KoinTypography.labelWeight,
                                    fontSize: KoinTypography.small,
                                    color: AppTheme.textLightColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(12),
                          AnimatedCounter(
                            value: item.amount,
                            formatter: (val) =>
                                currency.compactFormatter.format(val),
                            duration: const Duration(milliseconds: 1000),
                            style: TextStyle(
                              color: AppTheme.textColor(context),
                              fontWeight: KoinTypography.titleWeight,
                              fontSize: KoinTypography.compact,
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          height: 4,
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLightColor(context),
                          ),
                          child:
                              FractionallySizedBox(
                                    widthFactor: percent / 100,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        color: category.color,
                                      ),
                                    ),
                                  )
                                  .koinAnimate(
                                    context,
                                    autoPlay: !MediaQuery.disableAnimationsOf(
                                      context,
                                    ),
                                    onInit: KoinMotion.onInit(context),
                                  )
                                  .scaleX(
                                    alignment: Alignment.centerLeft,
                                    duration: 250.ms,
                                    curve: KoinMotion.curve,
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

  Widget _buildEmptyStateContent(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) => KoinEmptyState(
    fullScreen: true,
    icon: icon,
    title: title,
    subtitle: subtitle,
  );
}
