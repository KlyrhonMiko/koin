import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Content for patterned summary cards. Callers supply their amount widget to
/// preserve privacy masks, counter identity and feature-specific formatting.
class KoinSummaryContent extends StatelessWidget {
  const KoinSummaryContent({
    super.key,
    required this.label,
    required this.currencyCode,
    required this.amount,
    this.footer,
  });
  final String label;
  final String currencyCode;
  final Widget amount;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 44),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(label, style: KoinTypography.summaryLabelStyle),
            Text('·  $currencyCode', style: KoinTypography.summaryLabelStyle),
          ],
        ),
      ),
      const SizedBox(height: 16),
      amount,
      if (footer != null) ...[const SizedBox(height: 16), footer!],
    ],
  );
}
