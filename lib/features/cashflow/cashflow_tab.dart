import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:koin/core/core.dart';
import 'package:koin/features/cashflow/add_edit_cashflow_screen.dart';

/// Deep Cashflow Schedule Tab: Encapsulates recurring schedule listing, occurrence processing,
/// swipe-to-delete, and status tracking for both expenses and recurring incomes.
class CashflowScheduleTab extends ConsumerWidget {
  final TransactionType type;
  final bool showEntranceAnimations;

  const CashflowScheduleTab({
    super.key,
    required this.type,
    this.showEntranceAnimations = false,
  });

  bool get _isIncome => type == TransactionType.income;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(plannedPaymentProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountProvider).value ?? [];

    return paymentsAsync.when(
      data: (allPayments) {
        final payments = allPayments.where((p) => p.type == type).toList();

        if (payments.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () {
            HapticService.light();
            return ref
                .read(plannedPaymentProvider.notifier)
                .loadPlannedPayments();
          },
          color: AppTheme.primaryColor(context),
          backgroundColor: AppTheme.surfaceColor(context),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              KoinSpacing.screenInset,
              12,
              KoinSpacing.screenInset,
              100,
            ),
            itemCount: payments.length + 1,
            itemBuilder: (context, index) {
              if (index == payments.length) {
                return _buildAddButton(context);
              }

              final payment = payments[index];
              final category = categories
                  .where((c) => c.id == payment.categoryId)
                  .firstOrNull;

              final account = accounts
                  .where((a) => a.id == payment.accountId)
                  .firstOrNull;

              final tile = Padding(
                padding: const EdgeInsets.only(bottom: KoinSpacing.cardGap),
                child: SwipeToDeleteTile(
                  key: Key('cashflow_${payment.id}'),
                  borderRadius: BorderRadius.circular(24),
                  confirmTitle: _isIncome
                      ? 'Delete Recurring Income?'
                      : 'Delete Planned Payment?',
                  confirmDescription:
                      'Are you sure you want to delete "${payment.title}"? This action cannot be undone.',
                  confirmLabel: _isIncome
                      ? 'Delete Income'
                      : 'Delete Planned Payment',
                  onDelete: () async {
                    HapticService.heavy();
                    await ref
                        .read(plannedPaymentProvider.notifier)
                        .deletePlannedPayment(payment.id);
                  },
                  child: _buildCard(
                    context,
                    ref,
                    payment,
                    category,
                    account?.name,
                    currency.symbol,
                  ),
                ),
              );

              if (showEntranceAnimations) {
                return tile.koinEntrance(context);
              }
              return tile;
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          KoinErrorState(onRetry: () => ref.invalidate(plannedPaymentProvider)),
    );
  }

  Widget _buildEmptyState(BuildContext context) => KoinEmptyState.sliver(
    icon: _isIncome
        ? Icons.account_balance_wallet_rounded
        : Icons.event_repeat_rounded,
    title: _isIncome ? 'No recurring incomes' : 'No planned payments',
    subtitle: _isIncome
        ? 'Add regular income streams like salary or freelance retainers'
        : 'Add recurring payments to track your future obligations',
    action: KoinPrimaryButton(
      label: _isIncome ? 'Add Recurring Income' : 'Add Planned Payment',
      icon: Icons.add_rounded,
      onPressed: () {
        HapticService.medium();
        Navigator.push(
          context,
          SlideUpRoute(page: AddEditCashflowScreen(initialType: type)),
        );
      },
    ),
  );

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    PlannedPayment payment,
    TransactionCategory? category,
    String? accountName,
    String currencySymbol,
  ) {
    final catColor = category?.color ?? AppTheme.primaryColor(context);
    final isOverdue = payment.isOverdue();
    final isAvailable = payment.isEligible();
    final currency = ref.watch(settingsProvider).currency;

    return PressableScale(
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          SlideUpRoute(
            page: AddEditCashflowScreen(payment: payment, initialType: type),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOverdue && !_isIncome
                ? AppTheme.errorContentColor(context).withValues(alpha: 0.3)
                : AppTheme.textLightColor(context).withValues(alpha: 0.1),
            width: isOverdue && !_isIncome ? 1.5 : 1,
          ),
          boxShadow: [
            AppTheme.boxShadow(
              context,
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    category != null
                        ? IconUtils.getIcon(category.iconCodePoint)
                        : Icons.category_rounded,
                    color: catColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.title,
                        style: const TextStyle(
                          fontWeight: KoinTypography.titleWeight,
                          fontSize: KoinTypography.itemAmount,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: AppTheme.textLightColor(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            payment.frequency.label.toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.textLightColor(context),
                              fontSize: KoinTypography.overline,
                              fontWeight: KoinTypography.titleWeight,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (payment.isAutoProcess) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor(context)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 10,
                                    color: AppTheme.primaryColor(context),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'AUTO',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor(context),
                                      fontSize: KoinTypography.badgeLabel,
                                      fontWeight: KoinTypography.titleWeight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_isIncome ? '+' : '-'}${currency.formatter.format(payment.amount)}',
                  style: TextStyle(
                    fontWeight: KoinTypography.titleWeight,
                    fontSize: KoinTypography.itemAmount,
                    letterSpacing: KoinTypography.itemTracking,
                    color: _isIncome
                        ? AppTheme.incomeContentColor(context)
                        : AppTheme.expenseContentColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppTheme.textLightColor(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payment.frequency == PaymentFrequency.flexible
                                  ? 'Availability'
                                  : _isIncome
                                  ? 'Next Income Date'
                                  : 'Next Payment',
                              style: TextStyle(
                                color: AppTheme.textLightColor(context),
                                fontSize: KoinTypography.overline,
                                fontWeight: KoinTypography.supportingWeight,
                              ),
                            ),
                            Text(
                              payment.availabilityLabel(),
                              style: const TextStyle(
                                fontWeight: KoinTypography.titleWeight,
                                fontSize: KoinTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: !isAvailable
                      ? null
                      : () {
                          HapticService.light();
                          PaymentConfirmationSheet.confirmAndProcess(
                            context: context,
                            ref: ref,
                            payment: payment,
                          );
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        AppTheme.boxShadow(
                          context,
                          color: AppTheme.primaryColor(context)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      !isAvailable
                          ? 'Unavailable'
                          : _isIncome
                          ? 'Collect Now'
                          : 'Pay Now',
                      style: TextStyle(
                        color: Colors.white,

                        fontSize: KoinTypography.caption,
                        fontWeight: KoinTypography.titleWeight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: KoinAddButton(
        borderRadius: 20,
        label: _isIncome ? 'Add New Income' : 'Add New Payment',
        onPressed: () {
          HapticService.medium();
          Navigator.push(
            context,
            SlideUpRoute(page: AddEditCashflowScreen(initialType: type)),
          );
        },
      ),
    );
  }
}

/// Convenience view specialized for Planned Payments (expenses/bills/planned payments).
class PlannedPaymentsTab extends StatelessWidget {
  final bool showEntranceAnimations;

  const PlannedPaymentsTab({super.key, this.showEntranceAnimations = false});

  @override
  Widget build(BuildContext context) {
    return CashflowScheduleTab(
      type: TransactionType.expense,
      showEntranceAnimations: showEntranceAnimations,
    );
  }
}

/// Convenience view specialized for Recurring Incomes (salaries/retainers/dividends).
class RecurringIncomesTab extends StatelessWidget {
  final bool showEntranceAnimations;

  const RecurringIncomesTab({super.key, this.showEntranceAnimations = false});

  @override
  Widget build(BuildContext context) {
    return CashflowScheduleTab(
      type: TransactionType.income,
      showEntranceAnimations: showEntranceAnimations,
    );
  }
}
