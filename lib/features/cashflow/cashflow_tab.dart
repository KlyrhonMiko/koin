import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/core/widgets/koin_primary_button.dart';
import 'package:koin/core/widgets/payment_confirmation_sheet.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/widgets/swipe_to_delete_tile.dart';
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

    await ref.read(plannedPaymentProvider.notifier).processOccurrence(
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

  String _formatNextPaymentDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final paymentDate = DateTime(date.year, date.month, date.day);
    final difference = paymentDate.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference < -1) return '${difference.abs()} days overdue';
    if (difference < 7) return 'in $difference days';
    return DateFormat('MMM d, y').format(date);
  }

  int _getDaysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  Color _getDueDateColor(BuildContext context, DateTime date) {
    final days = _getDaysUntil(date);
    if (days < 0) return Colors.redAccent;
    if (days <= 2) return Colors.orangeAccent;
    return AppTheme.textLightColor(context);
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
            return ref.read(plannedPaymentProvider.notifier).loadPlannedPayments();
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
                    orElse: () => categories.isNotEmpty ? categories.first : null,
                  );

              final account = accounts
                  .where((a) => a.id == payment.accountId)
                  .firstOrNull;

              final tile = SwipeToDeleteTile(
                key: Key('cashflow_${payment.id}'),
                margin: const EdgeInsets.only(bottom: 16),
                borderRadius: BorderRadius.circular(24),
                confirmTitle: _isIncome ? 'Delete Recurring Income?' : 'Delete Subscription?',
                confirmDescription:
                    'Are you sure you want to delete "${payment.title}"? This action cannot be undone.',
                confirmLabel: _isIncome ? 'Delete Income' : 'Delete Subscription',
                onDelete: () {
                  HapticService.heavy();
                  ref.read(plannedPaymentProvider.notifier).deletePlannedPayment(payment.id);
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
                          color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isIncome ? Icons.account_balance_wallet_rounded : Icons.event_repeat_rounded,
                      size: 56,
                      color: AppTheme.primaryColor(context).withValues(alpha: 0.6),
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
                    label: _isIncome ? 'Add Your First Recurring Income' : 'Add Your First Subscription',
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
    final dueDateColor = _getDueDateColor(context, payment.nextDate);

    return PressableScale(
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          SlideUpRoute(
            page: AddEditCashflowScreen(
              payment: payment,
              initialType: type,
            ),
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
                    category != null ? IconUtils.getIcon(category.iconCodePoint) : Icons.category_rounded,
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
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
                    color: _isIncome ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: dueDateColor),
                    const SizedBox(width: 6),
                    Text(
                      _formatNextPaymentDate(payment.nextDate),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dueDateColor,
                      ),
                    ),
                    if (accountName != null) ...[
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: AppTheme.textLightColor(context))),
                      const SizedBox(width: 8),
                      Text(
                        accountName,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textLightColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                PressableScale(
                  onTap: () => _processPayment(context, ref, payment),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isIncome
                          ? AppTheme.incomeColor(context).withValues(alpha: 0.12)
                          : AppTheme.primaryColor(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isIncome ? Icons.download_rounded : Icons.check_rounded,
                          size: 14,
                          color: _isIncome ? AppTheme.incomeColor(context) : AppTheme.primaryColor(context),
                        ),
                        const Gap(6),
                        Text(
                          _isIncome ? 'Receive' : 'Pay',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isIncome ? AppTheme.incomeColor(context) : AppTheme.primaryColor(context),
                          ),
                        ),
                      ],
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
        margin: const EdgeInsets.only(bottom: 24, top: 4),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.textLightColor(context).withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 20,
              color: AppTheme.primaryColor(context),
            ),
            const SizedBox(width: 8),
            Text(
              _isIncome ? 'Add Recurring Income' : 'Add Subscription',
              style: TextStyle(
                color: AppTheme.primaryColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 15,
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

  const PlannedPaymentsTab({
    super.key,
    this.showEntranceAnimations = false,
  });

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

  const RecurringIncomesTab({
    super.key,
    this.showEntranceAnimations = false,
  });

  @override
  Widget build(BuildContext context) {
    return CashflowScheduleTab(
      type: TransactionType.income,
      showEntranceAnimations: showEntranceAnimations,
    );
  }
}
