import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

/// Shared purchase presentation for credit details and its draft editor.
class DebtPurchaseCard extends StatelessWidget {
  final DebtItem item;
  final List<TransactionCategory> categories;
  final NumberFormat currencyFormat;
  final Color color;
  final double paidAmount;

  const DebtPurchaseCard({
    super.key,
    required this.item,
    required this.categories,
    required this.currencyFormat,
    required this.color,
    this.paidAmount = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final category = categories
        .where((entry) => entry.id == item.categoryId)
        .firstOrNull;
    final iconColor = category?.color ?? color;
    final bool isFullyPaid = paidAmount >= item.amount;
    final bool isPartiallyPaid = paidAmount > 0.01 && paidAmount < item.amount;
    
    return Opacity(
      opacity: isFullyPaid ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFullyPaid 
                ? AppTheme.incomeColor(context).withValues(alpha: 0.5)
                : AppTheme.dividerColor(context).withValues(alpha: 0.3),
            width: isFullyPaid ? 1.5 : 1.0,
          ),
          boxShadow: [
            AppTheme.boxShadow(
              context,
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category != null
                        ? IconUtils.getIcon(category.iconCodePoint)
                        : Icons.shopping_bag_outlined,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontWeight: KoinTypography.titleWeight,
                          fontSize: KoinTypography.body,
                          decoration: isFullyPaid ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(4),
                      Text(
                        '${item.totalInstallments} payments • Starts ${DateFormat.MMMd().format(item.firstPaymentDate)}',
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: KoinTypography.small,
                          fontWeight: KoinTypography.supportingWeight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(item.amount),
                      style: TextStyle(
                        color: color,
                        fontWeight: KoinTypography.headingWeight,
                        fontSize: KoinTypography.itemTitle,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    if (isFullyPaid) ...[
                      const Gap(4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeColor(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Paid',
                          style: TextStyle(
                            color: AppTheme.incomeColor(context),
                            fontSize: KoinTypography.overline,
                            fontWeight: KoinTypography.headingWeight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (isPartiallyPaid) ...[
              const Gap(14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: paidAmount / item.amount,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
              const Gap(6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid Amount',
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: KoinTypography.overline,
                      fontWeight: KoinTypography.supportingWeight,
                    ),
                  ),
                  Text(
                    '${currencyFormat.format(paidAmount)} / ${currencyFormat.format(item.amount)}',
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: KoinTypography.overline,
                      fontWeight: KoinTypography.headingWeight,
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
}

class DebtPurchaseSectionHeader extends StatelessWidget {
  final int count;
  final Color color;
  const DebtPurchaseSectionHeader({
    super.key,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(
          'Sub-Plans / Purchases',
          style: TextStyle(
            color: AppTheme.textColor(context),
            fontSize: KoinTypography.sectionTitle,
            fontWeight: KoinTypography.headingWeight,
            letterSpacing: KoinTypography.headingTracking,
          ),
        ),
      ),
      const Gap(10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: KoinTypography.small,
            fontWeight: KoinTypography.headingWeight,
          ),
        ),
      ),
    ],
  );
}
