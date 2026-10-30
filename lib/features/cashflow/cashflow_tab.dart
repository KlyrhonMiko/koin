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
    final categories = ref.watch(categoriesProvider).value ?? [];

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
            padding: EdgeInsets.fromLTRB(
              KoinSpacing.screenInset,
              12,
              KoinSpacing.screenInset,
              KoinSpacing.bottomClearance(context),
            ),
            itemCount: payments.length + 1,
            itemBuilder: (context, index) {
              if (index == payments.length) {
                return _buildAddButton(context);
              }

              final payment = payments[index];
              final category = categories
                  .where((category) => category.id == payment.categoryId)
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
                  child: _buildCard(context, ref, payment, category),
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
  ) {
    final currency = ref.watch(settingsProvider).currency;
    final available = payment.canProcess();
    final overdue = payment.isOverdue();
    final moneyColor = _isIncome
        ? AppTheme.incomeContentColor(context)
        : AppTheme.expenseContentColor(context);
    final metadataStyle = PortfolioCardStyle.label(context).copyWith(
      fontSize: KoinTypography.small,
      fontWeight: KoinTypography.supportingWeight,
    );
    final cadence = [
      if (payment.frequency != PaymentFrequency.flexible)
        payment.frequency.label,
      if (payment.isAutoProcess) 'Automatic',
    ].join(' · ');

    return PressableScale(
      semanticLabel: 'Edit ${payment.title}',
      onTap: () => Navigator.push(
        context,
        SlideUpRoute(
          page: AddEditCashflowScreen(payment: payment, initialType: type),
        ),
      ),
      child: Container(
        padding: PortfolioCardStyle.padding,
        decoration: PortfolioCardStyle.decoration(context).copyWith(
          border: overdue && !_isIncome
              ? Border.all(
                  color: AppTheme.errorContentColor(context)
                      .withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                KoinIconBadge(
                  icon: category == null
                      ? KoinIcons.squaresFour
                      : IconUtils.getIcon(category.iconCodePoint),
                  color: category?.color ?? AppTheme.primaryColor(context),
                  size: 32,
                  iconSize: 18,
                  radius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.title,
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: KoinTypography.body,
                          fontWeight: KoinTypography.titleWeight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      OverflowBar(
                        alignment: MainAxisAlignment.spaceBetween,
                        overflowAlignment: OverflowBarAlignment.start,
                        spacing: 12,
                        overflowSpacing: 2,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_isIncome ? '+' : '-'}${currency.formatter.format(payment.amount)}',
                              style: PortfolioCardStyle.amount(context)
                                  .copyWith(color: moneyColor),
                            ),
                          ),
                          Text(
                            payment.availabilityLabel(),
                            semanticsLabel:
                                payment.frequency == PaymentFrequency.flexible
                                ? null
                                : '${_isIncome ? 'Next income' : 'Next payment'}: ${payment.availabilityLabel()}',
                            style: metadataStyle.copyWith(
                              color: overdue && !_isIncome
                                  ? AppTheme.errorContentColor(context)
                                  : AppTheme.textLightColor(context),
                            ),
                          ),
                        ],
                      ),
                      if (cadence.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(cadence, style: metadataStyle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: ValueKey('cashflow-action-${payment.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor(context),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                textStyle: KoinTypography.choiceLabelStyle,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KoinShape.field),
                ),
              ),
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
              icon: Icon(
                _isIncome ? KoinIcons.arrowDown : KoinIcons.arrowUp,
                size: 18,
              ),
              label: Text(
                !available
                    ? 'Unavailable'
                    : _isIncome
                    ? 'Collect income'
                    : 'Make payment',
              ),
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
