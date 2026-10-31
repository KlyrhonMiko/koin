import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/providers/effective_transaction_clock_provider.dart';

class SpendingTransactionsSheet extends ConsumerWidget {
  const SpendingTransactionsSheet({super.key, required this.range});

  final DateTimeRange range;

  static Future<void> show(BuildContext context, DateTimeRange range) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppTheme.surfaceColor(context),
        builder: (context) => SpendingTransactionsSheet(range: range),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final asOf = ref.watch(effectiveTransactionClockProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountProvider).value ?? [];
    final currency = ref.watch(settingsProvider).currency;
    final expenses =
        (transactions.value ?? [])
            .where(
              (tx) =>
                  tx.countsAsExpense &&
                  !tx.date.isAfter(asOf) &&
                  !tx.date.isBefore(range.start) &&
                  !tx.date.isAfter(range.end),
            )
            .toList()
          ..sort(TransactionPage.compare);
    final total = expenses.fold(0.0, (sum, tx) => sum + tx.amount);
    final sameDay = DateUtils.isSameDay(range.start, range.end);
    final dateLabel = sameDay
        ? DateFormat.yMMMMd().format(range.start)
        : DateFormat.yMMMM().format(range.start);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                KoinSpacing.screenInset,
                0,
                KoinSpacing.screenInset,
                16,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dateLabel,
                            style: TextStyle(
                              color: AppTheme.textColor(context),
                              fontSize: KoinTypography.sectionTitle,
                              fontWeight: KoinTypography.headingWeight,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close spending details',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(KoinIcons.x),
                        ),
                      ],
                    ),
                    if (transactions.hasValue) ...[
                      const Gap(8),
                      Text(
                        currency.formatter.format(total),
                        key: const ValueKey('spending-detail-total'),
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: KoinTypography.formTitle,
                          fontWeight: KoinTypography.headingWeight,
                        ),
                      ),
                      Text(
                        'Spent · ${expenses.length} ${expenses.length == 1 ? 'transaction' : 'transactions'}',
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: KoinTypography.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ...transactions.when<List<Widget>>(
              data: (_) => [
                if (expenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(KoinSpacing.screenInset),
                      child: Text(
                        sameDay
                            ? 'No spending on this day'
                            : 'No spending this month',
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      KoinSpacing.screenInset,
                      0,
                      KoinSpacing.screenInset,
                      MediaQuery.paddingOf(context).bottom +
                          KoinSpacing.sectionGap,
                    ),
                    sliver: SliverList.separated(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) => TransactionTile.resolve(
                        key: ValueKey('spending-detail-${expenses[index].id}'),
                        transaction: expenses[index],
                        categories: categories,
                        accounts: accounts,
                        currency: currency,
                        activityStyle: true,
                        showDate: !sameDay,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      separatorBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(left: 54),
                        child: Divider(
                          height: 1,
                          color: AppTheme.dividerColor(context),
                        ),
                      ),
                    ),
                  ),
              ],
              loading: () => const [
                SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, _) => [
                SliverToBoxAdapter(
                  child: KoinErrorState(
                    onRetry: () => ref.invalidate(transactionProvider),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
