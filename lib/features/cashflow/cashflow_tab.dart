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

              return tile.koinEntrance(
                context,
                enabled: showEntranceAnimations,
                token: 'cashflow_${payment.id}',
              );
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
    icon: _isIncome ? KoinIcons.wallet : KoinIcons.calendarDots,
    title: _isIncome ? 'No recurring incomes' : 'No planned payments',
    subtitle: _isIncome
        ? 'Add regular income streams like salary or freelance retainers'
        : 'Add recurring payments to track your future obligations',
    action: KoinPrimaryButton(
      label: _isIncome ? 'Add Recurring Income' : 'Add Planned Payment',
      icon: KoinIcons.plus,
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
    final currency = ref.watch(settingsProvider).currency;
    final available = payment.canProcess();
    final overdue = payment.isOverdue();
    final accent = category?.color ?? AppTheme.primaryColor(context);
    final moneyColor = _isIncome
        ? AppTheme.incomeContentColor(context)
        : AppTheme.expenseContentColor(context);
    final amount = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        '${_isIncome ? '+' : '-'}${currency.formatter.format(payment.amount)}',
        style: TextStyle(
          color: moneyColor,
          fontSize: KoinTypography.itemAmount,
          fontWeight: KoinTypography.titleWeight,
        ),
      ),
    );
    return PressableScale(
      semanticLabel: 'Edit ${payment.title}',
      onTap: () => Navigator.push(
        context,
        SlideUpRoute(
          page: AddEditCashflowScreen(payment: payment, initialType: type),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: overdue && !_isIncome
                ? AppTheme.errorContentColor(context).withValues(alpha: 0.3)
                : AppTheme.dividerColor(context),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final heading = Row(
              children: [
                KoinIconBadge(
                  icon: category == null
                      ? KoinIcons.squaresFour
                      : IconUtils.getIcon(category.iconCodePoint),
                  color: accent,
                  radius: 16,
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
                          fontSize: KoinTypography.body,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            payment.frequency.label.toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.textLightColor(context),
                              fontSize: KoinTypography.small,
                            ),
                          ),
                          if (payment.isAutoProcess)
                            Text(
                              'AUTO',
                              style: TextStyle(
                                color: AppTheme.contentColor(
                                  context,
                                  AppTheme.primaryColor(context),
                                ),
                                fontSize: KoinTypography.small,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!stacked) ...[
                  const SizedBox(width: 12),
                  Flexible(child: amount),
                ],
              ],
            );
            final date = Row(
              children: [
                Icon(
                  KoinIcons.calendarBlank,
                  size: 20,
                  color: AppTheme.textLightColor(context),
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
                            ? 'Next income'
                            : 'Next payment',
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: KoinTypography.small,
                        ),
                      ),
                      Text(
                        payment.availabilityLabel(),
                        style: const TextStyle(
                          fontWeight: KoinTypography.labelWeight,
                          fontSize: KoinTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final action = FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: available
                  ? () {
                      HapticService.light();
                      PaymentConfirmationSheet.confirmAndProcess(
                        context: context,
                        ref: ref,
                        payment: payment,
                      );
                    }
                  : null,
              child: Text(
                !available
                    ? 'Unavailable'
                    : _isIncome
                    ? 'Collect Now'
                    : 'Pay Now',
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                if (stacked) ...[const SizedBox(height: 12), amount],
                const SizedBox(height: 16),
                Divider(color: AppTheme.dividerColor(context)),
                const SizedBox(height: 12),
                if (stacked) ...[
                  date,
                  const SizedBox(height: 12),
                  action,
                ] else
                  Row(
                    children: [
                      Expanded(child: date),
                      const SizedBox(width: 12),
                      action,
                    ],
                  ),
              ],
            );
          },
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
