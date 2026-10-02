import 'package:flutter/material.dart';
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

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.accountName = 'Account',
    this.toAccountName,
    required this.currency,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.showTime = true,
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
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    bool showTime = true,
  }) {
    final cat = categories
        .where((c) => c.id == transaction.categoryId)
        .firstOrNull;

    final acc = accounts
        .where((a) => a.id == transaction.accountId)
        .firstOrNull;

    final toAcc = transaction.toAccountId != null
        ? accounts
            .where((a) => a.id == transaction.toAccountId)
            .firstOrNull
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    final typeColor = isTransfer
        ? AppTheme.transferColor(context)
        : (isIncome
            ? AppTheme.incomeColor(context)
            : AppTheme.expenseColor(context));

    final color = isTransfer ? typeColor : (category?.color ?? typeColor);

    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (category != null
            ? IconUtils.getIcon(category!.iconCodePoint)
            : (isIncome
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded));

    final categoryName = isTransfer ? 'Transfer' : (category?.name ?? 'Others');
    final displayTitle = transaction.note.isEmpty ? categoryName : transaction.note;

    final displaySubtitle = isTransfer
        ? (transaction.note.isEmpty
            ? '$accountName → ${toAccountName ?? 'Account'}'
            : 'Transfer • $accountName → ${toAccountName ?? 'Account'}')
        : (transaction.note.isEmpty
            ? accountName
            : '$categoryName • $accountName');

    final formattedAmount = NumberFormat.currency(
      symbol: currency.symbol,
    ).format(transaction.amount);

    final signedAmount = isTransfer
        ? formattedAmount
        : '${isIncome ? '+' : '-'}$formattedAmount';

    return PressableScale(
      onTap: onTap ??
          () {
            HapticService.light();
            Navigator.push(
              context,
              SlideUpRoute(
                page: AddTransactionScreen(editingTransaction: transaction),
              ),
            );
          },
      child: Padding(
        padding: padding,
        child: Row(
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
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(3),
                  Text(
                    displaySubtitle,
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.5,
                  ),
                ),
                if (showTime) ...[
                  const Gap(2),
                  Text(
                    DateFormat.jm().format(transaction.date),
                    style: TextStyle(
                      color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
}
