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

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(symbol: currency.symbol);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.15)),
        const Gap(8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            const Text(
              'Estimated balance',
              style: TextStyle(
                color: Colors.white,
                fontSize: KoinTypography.body,
              ),
            ),
            Text(
              format.format(forecast.predictedNetBalance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: KoinTypography.body,
                fontWeight: KoinTypography.headingWeight,
              ),
            ),
          ],
        ),
        if (forecast.firstShortfallDate != null) ...[
          const Gap(8),
          Text(
            'Review payments before ${DateFormat.MMMd().format(forecast.firstShortfallDate!)}.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: KoinTypography.small,
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => _showDetails(context, format),
            child: const Text('Forecast details'),
          ),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context, NumberFormat format) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceColor(context),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Forecast details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Gap(8),
              Text(switch (horizon) {
                ForecastHorizon.weekly => 'An estimate for the next 7 days.',
                ForecastHorizon.monthly => 'An estimate for the next month.',
                ForecastHorizon.yearly => 'An estimate for the next year.',
              }),
              const Gap(20),
              for (final metric in [
                ('Starting balance', forecast.currentBaseline),
                ('Expected income', forecast.forecastedInflow),
                ('Expected outgoings', forecast.forecastedOutflow),
                ('Estimated balance', forecast.predictedNetBalance),
              ]) ...[
                Text(metric.$1, style: Theme.of(context).textTheme.labelLarge),
                const Gap(4),
                Text(
                  format.format(metric.$2),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(16),
              ],
              if (forecast.firstShortfallDate != null) ...[
                Text(
                  'Payments to review',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(4),
                Text(
                  'Upcoming payments could exceed your available balance on ${DateFormat.MMMd().format(forecast.firstShortfallDate!)}. Check their timing against your next income.',
                ),
                const Gap(20),
              ],
              if (forecast.lowerNetBalance != null &&
                  forecast.upperNetBalance != null) ...[
                Text(
                  'Possible balance range',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(4),
                Text(
                  '${format.format(forecast.lowerNetBalance)} to ${format.format(forecast.upperNetBalance)}',
                ),
                const Gap(8),
                const Text(
                  'Based on past changes in income and spending. Your scheduled payments stay the same in this estimate.',
                ),
              ] else
                const Text(
                  'More history will help us estimate a balance range.',
                ),
              const Gap(16),
              Text(
                forecast.historyMonths == 0
                    ? 'There is not enough history yet to estimate everyday income and spending. This estimate uses your planned payments, debts, and savings goals.'
                    : 'This estimate combines your recent history with planned payments, debts, and money set aside for savings goals. Unscheduled income and spending are spread across the period.',
              ),
              const Gap(16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
