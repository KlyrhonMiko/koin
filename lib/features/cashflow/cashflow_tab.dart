import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

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

  Future<void> _processPayment(
    BuildContext context,
    WidgetRef ref,
    PlannedPayment payment,
  ) async {
    final result = await PaymentConfirmationSheet.show(
      context: context,
      payment: payment,
    );
    if (result == null || !context.mounted) return;

    await ref
        .read(plannedPaymentProvider.notifier)
        .processOccurrence(
          payment: payment,
          amount: result.amount,
          accountId: result.accountId,
          categoryId: result.categoryId,
        );

    if (context.mounted) {
      KoinSnackBar.success(
        context,
        _isIncome ? 'Income processed' : 'Payment processed',
        subtitle: _isIncome
            ? 'Your recurring income has been completed'
            : 'Your planned payment has been completed',
      );
    }
  }

  int _getDaysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }


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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: payments.length + 1,
            itemBuilder: (context, index) {
              if (index == payments.length) {
                return _buildAddButton(context);
              }

              final payment = payments[index];
              final category = categories
                  .cast<TransactionCategory?>()
                  .firstWhere(
                    (c) => c?.id == payment.categoryId,
                    orElse: () =>
                        categories.isNotEmpty ? categories.first : null,
                  );

              final account = accounts
                  .where((a) => a.id == payment.accountId)
                  .firstOrNull;

              final tile = SwipeToDeleteTile(
                key: Key('cashflow_${payment.id}'),
                margin: const EdgeInsets.only(bottom: 16),
                borderRadius: BorderRadius.circular(24),
                confirmTitle: _isIncome
                    ? 'Delete Recurring Income?'
                    : 'Delete Subscription?',
                confirmDescription:
                    'Are you sure you want to delete "${payment.title}"? This action cannot be undone.',
                confirmLabel: _isIncome
                    ? 'Delete Income'
                    : 'Delete Subscription',
                onDelete: () {
                  HapticService.heavy();
                  ref
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
              );

              if (showEntranceAnimations) {
                return tile
                    .animate()
                    .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      duration: 250.ms,
                      curve: Curves.easeOutCubic,
                    );
              }
              return tile;
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: const Alignment(0, -0.25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      _isIncome
                          ? Icons.account_balance_wallet_rounded
                          : Icons.event_repeat_rounded,
                      size: 56,
                      color: AppTheme.primaryColor(
                        context,
                      ).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isIncome ? 'No recurring incomes' : 'No subscriptions',
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isIncome
                        ? 'Add regular income streams like salary\nor freelance retainers'
                        : 'Add recurring payments to track\nyour future obligations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  KoinPrimaryButton(
                    label: _isIncome
                        ? 'Add Your First Recurring Income'
                        : 'Add Your First Subscription',
                    icon: Icons.add_rounded,
                    onPressed: () {
                      HapticService.medium();
                      Navigator.push(
                        context,
                        SlideUpRoute(
                          page: AddEditCashflowScreen(initialType: type),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    PlannedPayment payment,
    TransactionCategory? category,
    String? accountName,
    String currencySymbol,
  ) {
    final catColor = category?.color ?? AppTheme.primaryColor(context);
    final isOverdue = _getDaysUntil(payment.nextDate) < 0;

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
                ? Colors.redAccent.withValues(alpha: 0.3)
                : AppTheme.textLightColor(context).withValues(alpha: 0.1),
            width: isOverdue && !_isIncome ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
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
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
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
                            payment.frequency.name.toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.textLightColor(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.1),
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
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
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
                  '${_isIncome ? '+' : '-'}$currencySymbol${NumberFormat('#,##0.00').format(payment.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.5,
                    color: _isIncome
                        ? AppTheme.incomeColor(context)
                        : AppTheme.expenseColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: AppTheme.textLightColor(
                context,
              ).withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.frequency == PaymentFrequency.flexible
                              ? 'Availability'
                              : _isIncome
                                  ? 'Next Income Date'
                                  : 'Next Payment',
                          style: TextStyle(
                            color: AppTheme.textLightColor(
                              context,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          payment.frequency == PaymentFrequency.flexible
                              ? 'Available Anytime'
                              : DateFormat.yMMMd().format(payment.nextDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    HapticService.light();
                    _processPayment(context, ref, payment);
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
                        BoxShadow(
                          color: AppTheme.primaryColor(
                            context,
                          ).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _isIncome ? 'Collect Now' : 'Pay Now',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
    return PressableScale(
      onTap: () {
        HapticService.medium();
        Navigator.push(
          context,
          SlideUpRoute(page: AddEditCashflowScreen(initialType: type)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, top: 8),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: AppTheme.textLightColor(context),
              size: 20,
            ),
            const Gap(10),
            Text(
              _isIncome ? 'Add New Income' : 'Add New Payment',
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience view specialized for Planned Payments (expenses/bills/subscriptions).
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
