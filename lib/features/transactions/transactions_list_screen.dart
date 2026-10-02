import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/transactions/widgets/filter_bottom_sheet.dart';
import 'package:gap/gap.dart';

// Removed local AnimationTracker as it is now in core/utils/animation_utils.dart

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

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
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Align(
                          alignment: const Alignment(
                            0,
                            -0.3,
                          ), // Shifted up further from -0.2 to -0.3
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min, // Keep column compact
                            children:
                                [
                                      Container(
                                        padding: const EdgeInsets.all(36),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceColor(context),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryColor(
                                                context,
                                              ).withValues(alpha: 0.1),
                                              blurRadius: 40,
                                              spreadRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.receipt_long_rounded,
                                          size: 56,
                                          color: AppTheme.primaryColor(
                                            context,
                                          ).withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        filter.isEmpty
                                            ? 'No recent activity'
                                            : 'No results found',
                                        style: TextStyle(
                                          color: AppTheme.textColor(context),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        filter.isEmpty
                                            ? 'Transactions will appear here once added'
                                            : 'Try adjusting your search or filters',
                                        style: TextStyle(
                                          color: AppTheme.textLightColor(
                                            context,
                                          ).withValues(alpha: 0.6),
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (!filter.isEmpty) ...[
                                        const SizedBox(height: 32),
                                        PressableScale(
                                          onTap: () {
                                            HapticService.medium();
                                            filterNotifier.clearFilters();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor(
                                                context,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              'Clear all filters',
                                              style: TextStyle(
                                                color: AppTheme.primaryColor(
                                                  context,
                                                ),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ]
                                    .animate(interval: 40.ms)
                                    .fade(
                                      duration: 250.ms,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      duration: 250.ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Group transactions into deep domain TransactionGroups
                final groups = TransactionGroup.groupTransactions(transactions);
                final accounts = accountsAsync.value ?? [];

                return ListView.builder(
                  key: const ValueKey('transactions_list_builder'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: groups.length,
                  itemBuilder: (context, sectionIndex) {
                    final group = groups[sectionIndex];
                    final dateKey = group.dateKey;
                    final txList = group.transactions;
                    final dailyTotal = group.dailyTotal;

                    Widget dayGroup = Padding(
                      key: GlobalObjectKey('day_padding_$dateKey'),
                      padding: EdgeInsets.only(
                        bottom: sectionIndex == groups.length - 1 ? 0 : 20,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor(context),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Day Header
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppTheme.dividerColor(
                                        context,
                                      ).withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateKey.toUpperCase(),
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(
                                          context,
                                        ).withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (dailyTotal != 0)
                                      AnimatedCounter(
                                        key: ValueKey('total_$dateKey'),
                                        value: dailyTotal.abs(),
                                        animateFromZero:
                                            !AnimationTracker.isSeen(
                                              'day_$dateKey',
                                            ),
                                        lastValueToken: 'total_$dateKey',
                                        formatter: (v) {
                                          String fmtBalance =
                                              NumberFormat.currency(
                                                symbol: currency.symbol,
                                              ).format(v);
                                          if (dailyTotal > 0) {
                                            fmtBalance = '+$fmtBalance';
                                          }
                                          if (dailyTotal < 0) {
                                            fmtBalance = '-$fmtBalance';
                                          }
                                          return fmtBalance;
                                        },
                                        duration: const Duration(
                                          milliseconds: 1000,
                                        ),
                                        style: TextStyle(
                                          color: dailyTotal > 0
                                              ? AppTheme.incomeColor(context)
                                              : AppTheme.expenseColor(context),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // List of Transactions within the Day
                              ...txList.asMap().entries.map((entry) {
                                final i = entry.key;
                                final tx = entry.value;

                                final listItem = TransactionTile.resolve(
                                  transaction: tx,
                                  categories: categories,
                                  accounts: accounts,
                                  currency: currency,
                                );

                                Widget txAnimated = SwipeToDeleteTile(
                                  key: Key(tx.id),
                                  borderRadius: BorderRadius.zero,
                                  backgroundColor: AppTheme.errorColor(context),
                                  icon: Icons.delete_forever_rounded,
                                  confirmTitle: 'Delete Transaction?',
                                  confirmDescription:
                                      'This transaction will be permanently removed. This action cannot be undone.',
                                  onDelete: () {
                                    ref
                                        .read(transactionProvider.notifier)
                                        .deleteTransaction(tx.id);
                                  },
                                  child: listItem,
                                ).animate(key: ValueKey('tx_item_${tx.id}'));

                                if (!AnimationTracker.hasSeen('tx_${tx.id}')) {
                                  txAnimated = (txAnimated as Animate)
                                      .fade()
                                      .slideX(begin: 0.05);
                                }

                                return Column(
                                  key: ValueKey('group_item_${tx.id}'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    txAnimated,

                                    if (i < txList.length - 1)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ).copyWith(left: 64),
                                        child: Container(
                                          height: 1,
                                          color: AppTheme.dividerColor(
                                            context,
                                          ).withValues(alpha: 0.4),
                                        ),
                                      ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );

                    Widget dayGroupAnimated = dayGroup.animate(
                      key: GlobalObjectKey('day_group_$dateKey'),
                    );

                    if (!AnimationTracker.hasSeen('day_$dateKey')) {
                      dayGroupAnimated = (dayGroupAnimated as Animate)
                          .fadeIn(duration: 350.ms)
                          .slideY(
                            begin: 0.04,
                            duration: 350.ms,
                            curve: Curves.easeOutCubic,
                          );
                    }

                    return dayGroupAnimated;
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
                    Icons.search_rounded,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),

                // Search field
                Expanded(
                  child: TextField(
                    onChanged: (value) => filterNotifier.setQuery(value),
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
                      hintStyle: TextStyle(
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
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
                          Icons.tune_rounded,
                          color: hasFilters
                              ? primary
                              : AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.5),
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
                                  BoxShadow(
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
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
          if (hasFilters && filter.summaryText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child:
                  Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 13,
                            color: primary.withValues(alpha: 0.6),
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              filter.summaryText,
                              style: TextStyle(
                                color: AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Gap(8),
                          GestureDetector(
                            onTap: () {
                              HapticService.light();
                              filterNotifier.clearFilters();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .slideY(begin: -0.3, duration: 200.ms),
            ),
        ],
      ),
    );
  }
}
