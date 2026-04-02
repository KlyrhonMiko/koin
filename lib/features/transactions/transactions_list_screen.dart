import 'package:flutter/material.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/widgets/animated_counter.dart';
import 'package:koin/features/transactions/widgets/filter_bottom_sheet.dart';
import 'package:koin/core/models/transaction_filter.dart';
import 'package:gap/gap.dart';

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
        return ref.read(transactionProvider.notifier).loadTransactions();
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
                            children: [
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
                                  )
                                  .animate()
                                  .scale(
                                    delay: 200.ms,
                                    curve: Curves.easeOutBack,
                                    duration: 600.ms,
                                  )
                                  .fadeIn(),
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
                                  )
                                  .animate()
                                  .slideY(
                                    begin: 0.2,
                                    delay: 300.ms,
                                    duration: 400.ms,
                                  )
                                  .fadeIn(),
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
                                  )
                                  .animate()
                                  .slideY(
                                    begin: 0.2,
                                    delay: 400.ms,
                                    duration: 400.ms,
                                  )
                                  .fadeIn(),
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
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Clear all filters',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 500.ms),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Group transactions by date
                final grouped = <String, List<AppTransaction>>{};
                for (final tx in transactions) {
                  final key = DateFormat.yMMMd().format(tx.date);
                  grouped.putIfAbsent(key, () => []).add(tx);
                }
                final dateKeys = grouped.keys.toList();

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: dateKeys.length,
                  itemBuilder: (context, sectionIndex) {
                    final dateKey = dateKeys[sectionIndex];
                    final txList = grouped[dateKey]!;

                    double dailyTotal = 0;
                    for (var tx in txList) {
                      if (tx.type == TransactionType.income) {
                        dailyTotal += tx.amount;
                      } else if (tx.type == TransactionType.expense) {
                        dailyTotal -= tx.amount;
                      }
                    }

                    String formattedTotal = NumberFormat.currency(
                      symbol: currency.symbol,
                    ).format(dailyTotal.abs());
                    if (dailyTotal > 0) formattedTotal = '+$formattedTotal';
                    if (dailyTotal < 0) formattedTotal = '-$formattedTotal';

                    return Padding(
                          padding: EdgeInsets.only(
                            bottom: sectionIndex == dateKeys.length - 1
                                ? 0
                                : 20,
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
                                            value: dailyTotal.abs(),
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
                                                  ? AppTheme.incomeColor(
                                                      context,
                                                    )
                                                  : AppTheme.expenseColor(
                                                      context,
                                                    ),
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
                                    final isIncome =
                                        tx.type == TransactionType.income;
                                    final isTransfer =
                                        tx.type == TransactionType.transfer;

                                    final color = isTransfer
                                        ? AppTheme.transferColor(context)
                                        : (isIncome
                                              ? AppTheme.incomeColor(context)
                                              : AppTheme.expenseColor(context));

                                    final icon = isTransfer
                                        ? Icons.swap_horiz_rounded
                                        : (isIncome
                                              ? Icons.arrow_downward_rounded
                                              : Icons.arrow_upward_rounded);

                                    final categoryName =
                                        categories
                                            .where((c) => c.id == tx.categoryId)
                                            .map((c) => c.name)
                                            .firstOrNull ??
                                        'Others';

                                    final accountName = accountsAsync.when(
                                      data: (accounts) =>
                                          accounts
                                              .where(
                                                (a) => a.id == tx.accountId,
                                              )
                                              .map((a) => a.name)
                                              .firstOrNull ??
                                          'Account',
                                      loading: () => '...',
                                      error: (error, stack) => 'Error',
                                    );

                                    final displayTitle = tx.note.isEmpty
                                        ? categoryName
                                        : tx.note;
                                    final displaySubtitle = tx.note.isEmpty
                                        ? accountName
                                        : '$categoryName • $accountName';

                                    final listItem = PressableScale(
                                      onTap: () {
                                        HapticService.light();
                                        Navigator.push(
                                          context,
                                          SlideUpRoute(
                                            page: AddTransactionScreen(
                                              editingTransaction: tx,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                  alpha: 0.1,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                icon,
                                                color: color,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    displayTitle,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    displaySubtitle,
                                                    style: TextStyle(
                                                      color:
                                                          AppTheme.textLightColor(
                                                            context,
                                                          ),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  isTransfer
                                                      ? NumberFormat.currency(
                                                          symbol:
                                                              currency.symbol,
                                                        ).format(tx.amount)
                                                      : '${isIncome ? '+' : '-'}${NumberFormat.currency(symbol: currency.symbol).format(tx.amount)}',
                                                  style: TextStyle(
                                                    color: color,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  DateFormat.jm().format(
                                                    tx.date,
                                                  ),
                                                  style: TextStyle(
                                                    color:
                                                        AppTheme.textLightColor(
                                                          context,
                                                        ).withValues(
                                                          alpha: 0.6,
                                                        ),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Dismissible(
                                              key: Key(tx.id),
                                              direction:
                                                  DismissDirection.endToStart,
                                              onUpdate: (details) {
                                                if (details.reached &&
                                                    !details.previousReached) {
                                                  HapticService.selection();
                                                }
                                              },
                                              background: Container(
                                                color: AppTheme.errorColor(
                                                  context,
                                                ),
                                                alignment:
                                                    Alignment.centerRight,
                                                padding: const EdgeInsets.only(
                                                  right: 24,
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              onDismissed: (_) {
                                                ref
                                                    .read(
                                                      transactionProvider
                                                          .notifier,
                                                    )
                                                    .deleteTransaction(tx.id);
                                              },
                                              confirmDismiss: (direction) async {
                                                HapticService.medium();
                                                final result =
                                                    await ConfirmationSheet.show(
                                                      context: context,
                                                      title:
                                                          'Delete Transaction?',
                                                      description:
                                                          'This transaction will be permanently removed. This action cannot be undone.',
                                                      confirmLabel: 'Delete',
                                                      confirmColor:
                                                          AppTheme.errorColor(
                                                            context,
                                                          ),
                                                      icon: Icons
                                                          .delete_forever_rounded,
                                                      isDanger: true,
                                                    );
                                                return result ?? false;
                                              },
                                              child: listItem,
                                            )
                                            .animate()
                                            .fade(delay: (i * 40).ms)
                                            .slideX(begin: 0.05),

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
                        )
                        .animate()
                        .fadeIn(delay: (sectionIndex * 60).ms, duration: 350.ms)
                        .slideY(
                          begin: 0.04,
                          duration: 350.ms,
                          curve: Curves.easeOutCubic,
                        );
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

    // Count non-query filters
    int filterCount = 0;
    if (filter.type != null) filterCount++;
    if (filter.dateRange != null) filterCount++;
    if (filter.categoryIds.isNotEmpty) filterCount += filter.categoryIds.length;
    if (filter.accountIds.isNotEmpty) filterCount += filter.accountIds.length;
    if (filter.minAmount != null) filterCount++;
    if (filter.maxAmount != null) filterCount++;

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
          if (hasFilters)
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
                              _buildFilterSummary(filter),
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

  String _buildFilterSummary(TransactionFilter filter) {
    final parts = <String>[];
    if (filter.type != null) {
      parts.add(
        filter.type!.name[0].toUpperCase() + filter.type!.name.substring(1),
      );
    }
    if (filter.dateRange != null) {
      parts.add('Date range');
    }
    if (filter.categoryIds.isNotEmpty) {
      parts.add(
        '${filter.categoryIds.length} categor${filter.categoryIds.length == 1 ? 'y' : 'ies'}',
      );
    }
    if (filter.accountIds.isNotEmpty) {
      parts.add(
        '${filter.accountIds.length} account${filter.accountIds.length == 1 ? '' : 's'}',
      );
    }
    if (filter.minAmount != null || filter.maxAmount != null) {
      parts.add('Amount range');
    }
    return parts.join(' • ');
  }
}
