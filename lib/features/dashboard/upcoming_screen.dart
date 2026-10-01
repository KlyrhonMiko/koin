import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/debts.dart';
import 'package:koin/features/cashflow/cashflow.dart';

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  Future<void> _paySubscription(
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
        payment.type == TransactionType.income
            ? 'Income processed'
            : 'Payment recorded successfully',
        subtitle: payment.type == TransactionType.income
            ? 'Your recurring income has been completed'
            : 'Your payment history has been updated',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(plannedPaymentProvider);
    final debtsAsync = ref.watch(debtsProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor(context),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const KoinBackButton(),
                const Gap(16),
                Text(
                  'Upcoming',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: paymentsAsync.when(
              data: (payments) {
                final debts = debtsAsync.value ?? [];
                final upcomingDebts = debts
                    .where(
                      (d) =>
                          d.totalInstallments > 0 && d.currentAmount < d.amount,
                    )
                    .toList();

                final List<dynamic> allUpcoming = [
                  ...payments,
                  ...upcomingDebts,
                ];

                if (allUpcoming.isEmpty) {
                  return _buildEmptyUpcoming(context, ref);
                }

                allUpcoming.sort((a, b) {
                  final dateA = a is PlannedPayment
                      ? a.nextDate
                      : (a as Debt).nextDueDate;
                  final dateB = b is PlannedPayment
                      ? b.nextDate
                      : (b as Debt).nextDueDate;
                  return dateA.compareTo(dateB);
                });

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  physics: const BouncingScrollPhysics(),
                  itemCount: allUpcoming.length,
                  itemBuilder: (context, index) {
                    final item = allUpcoming[index];
                    Widget child;

                    if (item is PlannedPayment) {
                      final category =
                          categories.any((c) => c.id == item.categoryId)
                          ? categories.firstWhere(
                              (c) => c.id == item.categoryId,
                            )
                          : (categories.isNotEmpty ? categories.first : null);

                      child = _buildUpcomingPaymentItem(
                        context,
                        ref,
                        item,
                        category,
                        currency,
                      );
                    } else {
                      child = _buildUpcomingDebtItem(
                        context,
                        ref,
                        item as Debt,
                        currency,
                      );
                    }

                    return child
                        .animate()
                        .fade(delay: (index * 50).ms)
                        .slideY(begin: 0.1);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUpcoming(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: PressableScale(
          onTap: () {
            HapticService.medium();
            Navigator.push(
              context,
              SlideUpRoute(
                page: const AddEditCashflowScreen(
                  initialType: TransactionType.expense,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  size: 32,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.3),
                ),
                const Gap(12),
                Text(
                  'No upcoming payments',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Gap(4),
                Text(
                  'Tap to add your first subscription',
                  style: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingPaymentItem(
    BuildContext context,
    WidgetRef ref,
    PlannedPayment payment,
    dynamic category,
    dynamic currency,
  ) {
    final isExpense = payment.type == TransactionType.expense;
    final amountColor = isExpense
        ? AppTheme.expenseColor(context)
        : AppTheme.incomeColor(context);

    final categoryColor = category != null
        ? Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')))
        : AppTheme.primaryColor(context);

    return PressableScale(
      onTap: () {
        HapticService.light();
        _paySubscription(context, ref, payment);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category != null
                    ? IconUtils.getIcon(category.iconCodePoint)
                    : Icons.category_rounded,
                color: categoryColor,
                size: 20,
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    payment.frequency == PaymentFrequency.flexible
                        ? 'Anytime • Flexible'
                        : '${DateFormat.MMMMd().format(payment.nextDate)} • ${payment.frequency.name}',
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "${isExpense ? '-' : '+'}${NumberFormat.currency(symbol: currency.symbol).format(payment.amount)}",
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingDebtItem(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
    dynamic currency,
  ) {
    final isOwedToMe = debt.type == DebtType.owedToMe;
    final amountColor = isOwedToMe
        ? AppTheme.incomeColor(context)
        : AppTheme.expenseColor(context);

    return PressableScale(
      onTap: () {
        HapticService.light();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              AddRepaymentSheet(debt: debt, isIncrease: false),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOwedToMe
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: amountColor,
                size: 20,
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debt.personName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    '${DateFormat.MMMMd().format(debt.nextDueDate)} • Credit/IOU',
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "${!isOwedToMe ? '-' : '+'}${NumberFormat.currency(symbol: currency.symbol).format(debt.upcomingPaymentAmount)}",
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
