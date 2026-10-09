import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

/// One useful estimate up front; supporting figures are available on demand.
class ForecastSummary extends StatelessWidget {
  final ForecastData forecast;
  final Currency currency;
  final ForecastHorizon horizon;

  const ForecastSummary({
    super.key,
    required this.forecast,
    required this.currency,
    required this.horizon,
  });

  String get _periodLabel => switch (horizon) {
    ForecastHorizon.weekly => 'Next 7 days',
    ForecastHorizon.monthly => 'Next month',
    ForecastHorizon.yearly => 'Next year',
  };

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(symbol: currency.symbol);
    final shortfall = forecast.firstShortfallDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.15)),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 48),
            alignment: Alignment.centerLeft,
          ),
          onPressed: () => _showDetails(context, format),
          child: Row(
            children: [
              if (shortfall != null) ...[
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  semanticLabel:
                      'Review payments before ${DateFormat.MMMd().format(shortfall)}',
                ),
                const Gap(8),
              ],
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Forecast',
                      style: TextStyle(fontSize: KoinTypography.small),
                    ),
                    Text(
                      format.format(forecast.predictedNetBalance),
                      style: const TextStyle(
                        fontSize: KoinTypography.body,
                        fontWeight: KoinTypography.headingWeight,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ],
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
                  '$_periodLabel · Estimated balance',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Gap(8),
                Text(
                  format.format(forecast.predictedNetBalance),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: KoinTypography.headingWeight,
                  ),
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
                  format.format(forecast.currentBaseline),
                ),
                _metric(
                  context,
                  'Expected income',
                  format.format(forecast.forecastedInflow),
                ),
                _metric(
                  context,
                  'Expected outgoings',
                  format.format(forecast.forecastedOutflow),
                ),
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
                        '${format.format(forecast.lowerNetBalance)} to ${format.format(forecast.upperNetBalance)}',
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
                      forecast.historyMonths == 0
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
