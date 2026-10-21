import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

/// Open, compact estimate; spending remains the primary metric.
/// The horizon stays explicit and supporting figures open on demand.
class ForecastSummary extends StatelessWidget {
  final ForecastData forecast;
  final Currency currency;
  final ForecastHorizon horizon;
  final bool hideAmounts;

  const ForecastSummary({
    super.key,
    required this.forecast,
    required this.currency,
    required this.horizon,
    this.hideAmounts = false,
  });

  String _money(NumberFormat format, double? amount) =>
      hideAmounts ? '••••' : format.format(amount);

  String get _periodLabel => switch (horizon) {
    ForecastHorizon.weekly => 'Next 7 days',
    ForecastHorizon.monthly => 'Next month',
    ForecastHorizon.yearly => 'Next year',
  };

  bool get _limitedHistory => forecast.historyMonths < 3;

  String get _estimateLabel =>
      _limitedHistory ? 'Rough estimate' : 'Estimated balance';

  @override
  Widget build(BuildContext context) {
    final format = currency.formatter;
    final shortfall = forecast.firstShortfallDate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetails(context, format),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final estimate = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_periodLabel · $_estimateLabel',
                      style: TextStyle(
                        color: AppTheme.textLightColor(context),
                        fontSize: KoinTypography.small,
                        height: 1.4,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      _money(format, forecast.predictedNetBalance),
                      semanticsLabel: hideAmounts
                          ? 'Forecast balance hidden'
                          : null,
                      style: TextStyle(
                        color: AppTheme.textColor(context),
                        fontSize: KoinTypography.cardAmount,
                        fontWeight: KoinTypography.titleWeight,
                        letterSpacing: KoinTypography.itemTracking,
                        height: 1.2,
                      ),
                    ),
                  ],
                );
                final details = TextButton(
                  onPressed: () => _showDetails(context, format),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textLightColor(context),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Details'),
                );
                if (constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(12) > 18) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      estimate,
                      Align(alignment: Alignment.centerRight, child: details),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: estimate),
                    const Gap(12),
                    details,
                  ],
                );
              },
            ),
            if (hideAmounts) ...[
              const Gap(6),
              Text(
                'Summary amounts hidden',
                style: TextStyle(
                  color: AppTheme.textLightColor(context),
                  fontSize: KoinTypography.small,
                ),
              ),
            ],
            if (_limitedHistory) ...[
              const Gap(6),
              Text(
                forecast.historyDays != null
                    ? 'Based on ${forecast.historyDays} days · Limited history'
                    : 'Limited history · This estimate may change significantly',
                style: TextStyle(
                  color: AppTheme.textLightColor(context),
                  fontSize: KoinTypography.small,
                  height: 1.4,
                ),
              ),
            ],
            if (shortfall != null) ...[
              const Gap(6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppTheme.expenseColor(context),
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'Balance may run short on ${DateFormat.MMMd().format(shortfall)}',
                      style: TextStyle(
                        color: AppTheme.expenseColor(context),
                        fontSize: KoinTypography.small,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final labelWidget = Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          );
          final valueWidget = Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelWidget, const Gap(4), valueWidget],
                )
              : Row(
                  children: [
                    Expanded(child: labelWidget),
                    const Gap(12),
                    Flexible(fit: FlexFit.tight, child: valueWidget),
                  ],
                );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, NumberFormat format) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceColor(context),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Forecast details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Gap(4),
                Text(
                  '$_periodLabel · $_estimateLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Gap(8),
                Text(
                  _money(format, forecast.predictedNetBalance),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: KoinTypography.headingWeight),
                ),
                if (forecast.firstShortfallDate != null) ...[
                  const Gap(12),
                  Text(
                    'Your balance may run short on ${DateFormat.MMMd().format(forecast.firstShortfallDate!)}. Review upcoming payments.',
                  ),
                ],
                const Gap(16),
                _metric(
                  context,
                  'Starting balance',
                  _money(format, forecast.currentBaseline),
                ),
                _metric(
                  context,
                  'Expected income',
                  _money(format, forecast.forecastedInflow),
                ),
                _metric(
                  context,
                  'Expected outgoings',
                  _money(format, forecast.forecastedOutflow),
                ),
                if (forecast.savingsOutflow > 0) ...[
                  _metric(
                    context,
                    'Includes savings contributions',
                    _money(format, forecast.savingsOutflow),
                  ),
                  const Text(
                    'Assumes you keep funding your savings goals. Money set aside for savings stays yours.',
                  ),
                ],
                const Gap(8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: const Text('How this is estimated'),
                  children: [
                    if (forecast.lowerNetBalance != null &&
                        forecast.upperNetBalance != null) ...[
                      Text(
                        'Possible balance range',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Gap(4),
                      Text(
                        '${_money(format, forecast.lowerNetBalance)} to ${_money(format, forecast.upperNetBalance)}',
                      ),
                      const Gap(8),
                      const Text(
                        'Based on past changes in income and spending. Scheduled payments stay the same.',
                      ),
                      const Gap(12),
                    ] else ...[
                      const Text(
                        'More history will help us estimate a balance range.',
                      ),
                      const Gap(12),
                    ],
                    Text(
                      forecast.historyDays != null
                          ? 'Based on ${forecast.historyDays} complete days of income and spending. Large one-off transactions can skew this early estimate. Flexible payments use their recorded history; future income amounts and dates may vary.'
                          : forecast.historyMonths == 0
                          ? 'With no spending history yet, this estimate uses your planned payments, debts, and savings goals.'
                          : 'Based on recent income and spending, planned payments, debts, and savings goals. Unscheduled income and spending are spread across the period.',
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
