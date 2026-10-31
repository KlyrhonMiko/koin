import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/widgets/add_repayment_sheet.dart';

/// Reusable interactive tile for an [UpcomingEntry] in the timeline,
/// handling both recurring cashflow schedules and debt installments.
class UpcomingEntryTile extends StatelessWidget {
  final UpcomingEntry entry;
  final Currency currency;
  final TransactionCategory? category;
  final Future<void> Function(PlannedPayment payment)? onPayPayment;
  final void Function(Debt debt)? onRepayDebt;
  final EdgeInsetsGeometry margin;

  const UpcomingEntryTile({
    super.key,
    required this.entry,
    required this.currency,
    this.category,
    this.onPayPayment,
    this.onRepayDebt,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = entry.isExpense;
    final amountColor = isExpense
        ? AppTheme.expenseContentColor(context)
        : AppTheme.incomeContentColor(context);

    Color iconBgColor;

    if (entry.isPayment) {
      final catColor = category != null
          ? Color(int.parse(category!.colorHex.replaceFirst('#', '0xFF')))
          : AppTheme.primaryColor(context);
      iconBgColor = catColor;
    } else {
      iconBgColor = amountColor;
    }

    return PressableScale(
      onTap: () {
        if (entry.isPayment && entry.plannedPayment != null) {
          onPayPayment?.call(entry.plannedPayment!);
        } else if (entry.isDebt && entry.debt != null) {
          if (onRepayDebt != null) {
            onRepayDebt!(entry.debt!);
          } else {
            AddRepaymentSheet.show(context, debt: entry.debt!);
          }
        }
      },
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            AppTheme.boxShadow(
              context,
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final amountLabel =
                '${isExpense ? '-' : '+'}${currency.formatter.format(entry.amount)}';
            final amountStyle = TextStyle(
              color: amountColor,
              fontWeight: KoinTypography.headingWeight,
              fontSize: KoinTypography.body,
            );
            final amountMeasure = TextPainter(
              text: TextSpan(
                text: amountLabel,
                style: DefaultTextStyle.of(context).style.merge(amountStyle),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final detailsWidth = constraints.maxWidth - 44 - 14;
            final stacked =
                detailsWidth < 220 ||
                MediaQuery.textScalerOf(context).scale(15) > 20 ||
                amountMeasure.width + 8 + 100 > detailsWidth;
            amountMeasure.dispose();
            final amount = Text(
              amountLabel,
              style: amountStyle,
              maxLines: 1,
              softWrap: false,
            );
            final title = Text(
              entry.title,
              maxLines: stacked ? null : 1,
              overflow: stacked ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textColor(context),
                fontWeight: KoinTypography.titleWeight,
                fontSize: KoinTypography.body,
              ),
            );
            final subtitle = Text(
              '${entry.isAutoProcess ? 'Automatic · ' : ''}${entry.isFlexible ? 'Available anytime' : '${DateFormat.MMMMd().format(entry.dueDate)} · ${entry.formattedDueStatus()}'}',
              style: TextStyle(
                color: entry.isOverdue()
                    ? AppTheme.expenseContentColor(context)
                    : AppTheme.textLightColor(context),
                fontSize: KoinTypography.small,
                fontWeight: KoinTypography.supportingWeight,
              ),
            );
            return Row(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                KoinIconBadge(
                  icon: entry.isPayment
                      ? category == null
                            ? KoinIcons.squaresFour
                            : IconUtils.getIcon(category!.iconCodePoint)
                      : entry.isExpense
                      ? KoinIcons.arrowUp
                      : KoinIcons.arrowDown,
                  color: iconBgColor,
                  size: 44,
                  iconSize: 20,
                  radius: 12,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      if (stacked) ...[
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: amount,
                        ),
                      ],
                      const SizedBox(height: 4),
                      subtitle,
                    ],
                  ),
                ),
                if (!stacked) ...[const SizedBox(width: 8), amount],
              ],
            );
          },
        ),
      ),
    );
  }
}
