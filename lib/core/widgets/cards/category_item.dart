import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/icon_utils.dart';

import '../primitives/pressable_scale.dart';

/// The category manager's card, shared with archive management.
class CategoryItem extends StatelessWidget {
  const CategoryItem({
    super.key,
    required this.category,
    required this.currency,
    required this.onTap,
    this.leading,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final TransactionCategory category;
  final Currency currency;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onTap,
    child: Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const Gap(8)],
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                AppTheme.boxShadow(
                  context,
                  color: category.color.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              IconUtils.getIcon(category.iconCodePoint),
              color: category.color,
              size: 22,
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  maxLines:
                      MediaQuery.textScalerOf(context)
                              .scale(KoinTypography.body) >
                          24
                      ? 2
                      : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: KoinTypography.titleWeight,
                    fontSize: KoinTypography.body,
                    letterSpacing: KoinTypography.itemTracking,
                  ),
                ),
                if (category.type == TransactionType.expense &&
                    category.hasBudget) ...[
                  const Gap(4),
                  Text(
                    category.isPercentBudget
                        ? 'Budget: ${category.budgetPercent?.toStringAsFixed(0)}% of income'
                        : 'Budget: ${currency.formatter.format(category.budget)}',
                    maxLines:
                        MediaQuery.textScalerOf(context)
                                .scale(KoinTypography.body) >
                            24
                        ? 2
                        : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: KoinTypography.small,
                      fontWeight: KoinTypography.supportingWeight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(8),
          trailing ??
              Icon(
                KoinIcons.caretRight,
                size: 20,
                color: AppTheme.textLightColor(context).withValues(alpha: 0.4),
              ),
        ],
      ),
    ),
  );
}
