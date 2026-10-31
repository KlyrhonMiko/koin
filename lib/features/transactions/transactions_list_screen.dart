import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/transactions/widgets/filter_bottom_sheet.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/providers/transaction_history_provider.dart';

// Removed local AnimationTracker as it is now in core/utils/animation_utils.dart

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(pagedTransactionRowsProvider);
    final history = ref.watch(transactionHistoryProvider).value;

    final filter = ref.watch(transactionFilterProvider);
    final filterNotifier = ref.read(transactionFilterProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accountsAsync = ref.watch(accountProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return RefreshIndicator(
      onRefresh: () {
        HapticService.light();
        return ref
            .read(transactionProvider.notifier)
            .loadTransactions(showLoading: false);
      },
      color: AppTheme.primaryColor(context),
      backgroundColor: AppTheme.surfaceColor(context),
      child: Column(
        children: [
          _buildSearchAndFilterHeader(context, ref, filter, filterNotifier),
          Expanded(
            child: rowsAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return KoinEmptyState.sliver(
                    icon: KoinIcons.receipt,
                    title: filter.isEmpty
                        ? 'No recent activity'
                        : 'No results found',
                    subtitle: filter.isEmpty
                        ? 'Transactions will appear here once added'
                        : 'Try adjusting your search or filters',
                    action: filter.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () {
                              HapticService.medium();
                              filterNotifier.clearFilters();
                            },
                            child: const Text('Clear all filters'),
                          ),
                  );
                }

                final accounts = accountsAsync.value ?? [];
                return ListView.builder(
                  key: const ValueKey('transactions_list_builder'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    KoinSpacing.screenInset,
                    16,
                    KoinSpacing.screenInset,
                    KoinSpacing.bottomClearance(context),
                  ),
                  itemCount: rows.length + (history?.next != null ? 1 : 0),
                  itemBuilder: (context, rowIndex) {
                    if (rowIndex == rows.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: history!.loadingMore
                            ? const Center(child: CircularProgressIndicator())
                            : TextButton(
                                onPressed: () => ref
                                    .read(transactionHistoryProvider.notifier)
                                    .loadMore(),
                                child: Text(
                                  history.loadMoreError
                                      ? 'Could not load more. Retry'
                                      : 'Load more transactions',
                                ),
                              ),
                      );
                    }
                    final row = rows[rowIndex];
                    final group = row.group;
                    if (row.index == -1) {
                      final total = group.dailyTotal;
                      return Padding(
                        key: ValueKey('day_${group.dateKey}'),
                        padding: EdgeInsets.fromLTRB(
                          0,
                          rowIndex == 0 ? 8 : 24,
                          0,
                          8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.dateKey.toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.textLightColor(context),
                                  fontSize: KoinTypography.overline,
                                  fontWeight: KoinTypography.titleWeight,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (total != 0)
                              AnimatedCounter(
                                key: ValueKey('total_${group.dateKey}'),
                                value: total.abs(),
                                animateFromZero: !AnimationTracker.isSeen(
                                  'day_${group.dateKey}',
                                ),
                                lastValueToken: 'total_${group.dateKey}',
                                formatter: (value) =>
                                    '${total > 0 ? '+' : '-'}${currency.formatter.format(value)}',
                                style: TextStyle(
                                  color: total > 0
                                      ? AppTheme.incomeContentColor(context)
                                      : AppTheme.expenseContentColor(context),
                                  fontSize: KoinTypography.caption,
                                  fontWeight: KoinTypography.titleWeight,
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    final tx = group.transactions[row.index];
                    final isTransfer =
                        tx.transferId != null ||
                        tx.type == TransactionType.transfer;
                    return Column(
                      key: ValueKey('group_item_${tx.id}'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwipeToDeleteTile(
                          key: Key(tx.id),
                          borderRadius: BorderRadius.zero,
                          backgroundColor: AppTheme.errorColor(context),
                          icon: KoinIcons.trash,
                          confirmTitle: isTransfer
                              ? 'Delete transfer and fee?'
                              : tx.plannedPaymentId != null
                              ? 'Delete scheduled entry?'
                              : 'Delete Transaction?',
                          confirmDescription: isTransfer
                              ? 'The entire transfer and its linked fee will be removed. Any savings released for them will be restored.'
                              : tx.plannedPaymentId != null
                              ? 'This entry will be removed. For manual schedules, only the latest tracked occurrence of an unchanged schedule becomes due again. Other occurrences stay skipped.'
                              : 'This transaction will be permanently removed. Any savings released for it will be restored. This action cannot be undone.',
                          onDelete: () => ref
                              .read(transactionProvider.notifier)
                              .deleteTransaction(tx.transferId ?? tx.id),
                          child: TransactionTile.resolve(
                            transaction: tx,
                            categories: categories,
                            accounts: accounts,
                            currency: currency,
                            activityStyle: true,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ).koinEntrance(context, token: 'tx_${tx.id}'),
                        if (row.index < group.transactions.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 54),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: AppTheme.dividerColor(context)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => KoinErrorState(
                onRetry: () => ref.invalidate(transactionHistoryProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterHeader(
    BuildContext context,
    WidgetRef ref,
    TransactionFilter filter,
    TransactionFilterNotifier filterNotifier,
  ) {
    final primary = AppTheme.primaryColor(context);
    final hasFilters = !filter.isEmpty;
    final filterCount = filter.activeFilterCount;
    final summary = filter.describe(
      categories: {
        for (final c
            in ref.watch(categoriesProvider).value ?? <TransactionCategory>[])
          c.id: c.name,
      },
      accounts: {
        for (final a in ref.watch(accountProvider).value ?? <Account>[])
          a.id: a.name,
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KoinSpacing.screenInset,
        4,
        KoinSpacing.screenInset,
        12,
      ),
      child: Column(
        children: [
          // ── Unified search + filter capsule ──
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLightColor(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                // Search icon
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(
                    KoinIcons.magnifyingGlass,
                    color: AppTheme.textLightColor(context)
                        .withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),

                // Search field
                Expanded(
                  child: KoinSearchField(
                    value: filter.query,
                    hintText: 'Search notes or categories',
                    onChanged: filterNotifier.setQuery,
                  ),
                ),

                // Divider line
                Container(
                  width: 1,
                  height: 24,
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
                ),

                // Filter button
                PressableScale(
                  enableHaptic: false,
                  semanticLabel: 'Filter transactions',
                  onTap: () {
                    HapticService.light();
                    FilterBottomSheet.show(context);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: hasFilters
                          ? primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(17),
                        bottomRight: Radius.circular(17),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          KoinIcons.slidersHorizontal,
                          color: hasFilters
                              ? primary
                              : AppTheme.textLightColor(context)
                                    .withValues(alpha: 0.5),
                          size: 20,
                        ),
                        if (filterCount > 0)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  AppTheme.boxShadow(
                                    context,
                                    color: primary.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '$filterCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: KoinTypography.badgeLabel,
                                    fontWeight: KoinTypography.titleWeight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Active filter summary strip ──
          if (hasFilters && summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child:
                  Row(
                        children: [
                          Icon(
                            KoinIcons.funnelSimple,
                            size: 13,
                            color: primary.withValues(alpha: 0.6),
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              summary,
                              style: TextStyle(
                                color: AppTheme.textLightColor(context)
                                    .withValues(alpha: 0.7),
                                fontSize: KoinTypography.overline,
                                fontWeight: KoinTypography.labelWeight,
                              ),
                            ),
                          ),
                          const Gap(8),
                          TextButton(
                            onPressed: filterNotifier.clearFilters,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      )
                      .koinAnimate(
                        context,
                        autoPlay: !MediaQuery.disableAnimationsOf(context),
                        onInit: KoinMotion.onInit(context),
                      )
                      .fadeIn(duration: 200.ms)
                      .slideY(begin: -0.3, duration: 200.ms),
            ),
        ],
      ),
    );
  }
}
