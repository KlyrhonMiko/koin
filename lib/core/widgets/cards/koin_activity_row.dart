import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Shared flat activity layout; domain formatting, editing and deletion stay
/// with the transaction, savings or debt feature.
class KoinActivityRow extends StatelessWidget {
  const KoinActivityRow({
    super.key,
    required this.leading,
    required this.title,
    required this.amount,
    required this.subtitle,
    this.stackedTitleMaxLines = 2,
    this.titleColor,
  });

  final Widget leading;
  final String title;
  final Widget amount;
  final Widget subtitle;
  final int? stackedTitleMaxLines;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      leading,
      const SizedBox(width: 14),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 220 ||
                MediaQuery.textScalerOf(context).scale(15) > 20;
            final heading = Text(
              title,
              maxLines: stacked ? stackedTitleMaxLines : 1,
              overflow: stacked && stackedTitleMaxLines == null
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor ?? AppTheme.textColor(context),
                fontSize: KoinTypography.body,
                fontWeight: KoinTypography.titleWeight,
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stacked) ...[
                  heading,
                  const SizedBox(height: 4),
                  amount,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: 12),
                      Flexible(fit: FlexFit.tight, child: amount),
                    ],
                  ),
                const SizedBox(height: 4),
                subtitle,
              ],
            );
          },
        ),
      ),
    ],
  );
}
