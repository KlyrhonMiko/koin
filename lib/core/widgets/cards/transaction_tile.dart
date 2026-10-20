import 'package:flutter/material.dart';

import 'koin_activity_row.dart';
import '../primitives/koin_icon_badge.dart';

import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/accounts/account.dart';
import 'package:koin/core/models/transactions/category.dart';
import 'package:koin/core/models/transactions/currency.dart';
import 'package:koin/core/models/transactions/transaction.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:koin/core/widgets/primitives/pressable_scale.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/providers/transaction_provider.dart';

/// Deep UI Component: Encapsulates transaction row presentation, icon and badge resolution,
/// subtitle route formatting (e.g. transfer source → destination), signed currency formatting,
/// and edit navigation.
class TransactionTile extends StatelessWidget {
  final AppTransaction transaction;
  final TransactionCategory? category;
  final String accountName;
  final String? toAccountName;
  final Currency currency;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool showTime;
  final bool activityStyle;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.accountName = 'Account',
    this.toAccountName,
    required this.currency,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: KoinSpacing.screenInset,
      vertical: 14,
    ),
    this.showTime = true,
    this.activityStyle = false,
  });

  /// Convenience factory resolving [category], [accountName], and [toAccountName]
  /// directly from domain lists.
  factory TransactionTile.resolve({
    Key? key,
    required AppTransaction transaction,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
    required Currency currency,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: KoinSpacing.screenInset,
      vertical: 14,
    ),
    bool showTime = true,
    bool activityStyle = false,
  }) {
    final cat = categories
        .where((c) => c.id == transaction.categoryId)
        .firstOrNull;

    final acc = accounts
        .where((a) => a.id == transaction.accountId)
        .firstOrNull;

    final toAcc = transaction.toAccountId != null
        ? accounts.where((a) => a.id == transaction.toAccountId).firstOrNull
        : null;

    return TransactionTile(
      key: key,
      transaction: transaction,
      category: cat,
      accountName: acc?.name ?? 'Account',
      toAccountName: toAcc?.name,
      currency: currency,
      onTap: onTap,
      padding: padding,
      showTime: showTime,
      activityStyle: activityStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    final typeColor = isTransfer
        ? AppTheme.transferContentColor(context)
        : (isIncome
              ? AppTheme.incomeContentColor(context)
              : AppTheme.expenseContentColor(context));

    final color = isTransfer ? typeColor : (category?.color ?? typeColor);

    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (category != null
              ? IconUtils.getIcon(category!.iconCodePoint)
              : (isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded));

    final categoryName = isTransfer
        ? 'Transfer'
        : (category?.name ?? 'Uncategorized');
    final displayTitle = transaction.note.isEmpty
        ? categoryName
        : transaction.note;

    final displaySubtitle = isTransfer
        ? (transaction.note.isEmpty
              ? '$accountName → ${toAccountName ?? 'Account'}'
              : 'Transfer • $accountName → ${toAccountName ?? 'Account'}')
        : (transaction.note.isEmpty
              ? accountName
              : '$categoryName • $accountName');

    final formattedAmount = currency.formatter.format(transaction.amount);

    final signedAmount = isTransfer
        ? formattedAmount
        : '${isIncome ? '+' : '-'}$formattedAmount';

    return PressableScale(
      onTap:
          onTap ??
          () {
            HapticService.light();
            final editing = transaction.transferId == null
                ? transaction
                : ProviderScope.containerOf(context)
                          .read(transactionProvider)
                          .value
                          ?.where((tx) => tx.id == transaction.transferId)
                          .firstOrNull ??
                      transaction;
            Navigator.push(
              context,
              SlideUpRoute(
                page: AddTransactionScreen(editingTransaction: editing),
              ),
            );
          },
      child: Padding(
        padding: padding,
        child: activityStyle
            ? _activityRow(
                context,
                icon: icon,
                color: color,
                title: displayTitle,
                subtitle: showTime
                    ? '$displaySubtitle · ${DateFormat.jm().format(transaction.date)}'
                    : displaySubtitle,
                amount: signedAmount,
                amountColor: typeColor,
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: const TextStyle(
                            fontWeight: KoinTypography.titleWeight,
                            fontSize: KoinTypography.body,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(3),
                        Text(
                          displaySubtitle,
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
                        signedAmount,
                        style: TextStyle(
                          color: typeColor,

                          fontWeight: KoinTypography.headingWeight,
                          fontSize: KoinTypography.body,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (showTime) ...[
                        const Gap(2),
                        Text(
                          DateFormat.jm().format(transaction.date),
                          style: TextStyle(
                            color: AppTheme.textLightColor(context)
                                .withValues(alpha: 0.6),
                            fontSize: KoinTypography.overline,
                            fontWeight: KoinTypography.labelWeight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _activityRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String amount,
    required Color amountColor,
  }) => KoinActivityRow(
    leading: KoinIconBadge(icon: icon, color: color),
    title: title,
    amount: Text(
      amount,
      textAlign: TextAlign.end,
      style: TextStyle(
        color: amountColor,
        fontSize: KoinTypography.itemAmount,
        fontWeight: KoinTypography.titleWeight,
        letterSpacing: KoinTypography.itemTracking,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(
        color: AppTheme.textLightColor(context),
        fontSize: KoinTypography.small,
        fontWeight: KoinTypography.supportingWeight,
      ),
    ),
  );
}
