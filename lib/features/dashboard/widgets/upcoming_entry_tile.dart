import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
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

  const UpcomingEntryTile({
    super.key,
    required this.entry,
    required this.currency,
    this.category,
    this.onPayPayment,
    this.onRepayDebt,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = entry.isExpense;
    final amountColor = isExpense
        ? AppTheme.expenseColor(context)
        : AppTheme.incomeColor(context);

    Color iconBgColor;
    Widget iconWidget;

    if (entry.isPayment) {
      final catColor = category != null
          ? Color(int.parse(category!.colorHex.replaceFirst('#', '0xFF')))
          : AppTheme.primaryColor(context);
      iconBgColor = catColor;
      iconWidget = Icon(
        category != null
            ? IconUtils.getIcon(category!.iconCodePoint)
            : Icons.category_rounded,
        color: catColor,
        size: 20,
      );
    } else {
      iconBgColor = amountColor;
      iconWidget = Icon(
        entry.isExpense
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        color: amountColor,
        size: 20,
      );
    }

    return PressableScale(
      onTap: () {
        HapticService.light();
        if (entry.isPayment && entry.plannedPayment != null) {
          onPayPayment?.call(entry.plannedPayment!);
        } else if (entry.isDebt && entry.debt != null) {
          if (onRepayDebt != null) {
            onRepayDebt!(entry.debt!);
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) =>
                  AddRepaymentSheet(debt: entry.debt!, isIncrease: false),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: iconWidget,
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isAutoProcess) ...[
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AUTO',
                            style: TextStyle(
                              color: AppTheme.primaryColor(context),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Gap(4),
                  Text(
                    '${DateFormat.MMMMd().format(entry.dueDate)} • ${entry.formattedDueStatus()}',
                    style: TextStyle(
                      color: entry.isOverdue()
                          ? AppTheme.expenseColor(context)
                          : AppTheme.textLightColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(8),
            Text(
              "${isExpense ? '-' : '+'}${NumberFormat.currency(symbol: currency.symbol).format(entry.amount)}",
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
