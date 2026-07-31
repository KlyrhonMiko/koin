import 'package:flutter/material.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/features/planned_payments/add_edit_planned_payment_screen.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/widgets/payment_confirmation_sheet.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';

class PlannedPaymentsScreen extends ConsumerWidget {
  const PlannedPaymentsScreen({super.key});

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

    final transaction = AppTransaction(
      id: const Uuid().v4(),
      note: '${payment.title} (Subscription)',
      amount: result.amount,
      type: payment.type,
      date: DateTime.now(),
      categoryId: result.categoryId,
      accountId: result.accountId,
      plannedPaymentId: payment.id,
    );

    DateTime nextDate = payment.nextDate;
    switch (payment.frequency) {
      case PaymentFrequency.daily:
        nextDate = nextDate.add(const Duration(days: 1));
        break;
      case PaymentFrequency.weekly:
        nextDate = nextDate.add(const Duration(days: 7));
        break;
      case PaymentFrequency.biWeekly:
        nextDate = nextDate.add(const Duration(days: 14));
        break;
      case PaymentFrequency.monthly:
        nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        break;
      case PaymentFrequency.quarterly:
        nextDate = DateTime(nextDate.year, nextDate.month + 3, nextDate.day);
        break;
      case PaymentFrequency.yearly:
        nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
        break;
    }

    final updatedPayment = PlannedPayment(
      id: payment.id,
      title: payment.title,
      amount: payment.amount,
      type: payment.type,
      categoryId: payment.categoryId,
      accountId: payment.accountId,
      startDate: payment.startDate,
      endDate: payment.endDate,
      nextDate: nextDate,
      frequency: payment.frequency,
      notes: payment.notes,
      isAutoProcess: payment.isAutoProcess,
    );

    await ref.read(transactionProvider.notifier).addTransaction(transaction);
    await ref
        .read(plannedPaymentProvider.notifier)
        .updatePlannedPayment(updatedPayment);

    if (context.mounted) {
      KoinSnackBar.success(
        context,
        'Payment processed',
        subtitle: 'Your planned payment has been completed',
      );
    }
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    PlannedPayment payment,
  ) async {
    return await ConfirmationSheet.show(
      context: context,
      title: 'Delete Subscription?',
      description:
          'Are you sure you want to delete "${payment.title}"? This action cannot be undone.',
      confirmLabel: 'Delete Subscription',
      confirmColor: AppTheme.expenseColor(context),
      icon: Icons.delete_outline_rounded,
      isDanger: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(plannedPaymentProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final categories = ref.watch(categoriesProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text(
          'Subscriptions',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surfaceColor(context),
        elevation: 0,
      ),
      body: paymentsAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return const Center(child: Text('No subscriptions found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              final category = categories.firstWhere(
                (c) => c.id == payment.categoryId,
                orElse: () => categories.first,
              );

              final isExpense = payment.type == TransactionType.expense;
              final amountColor = isExpense
                  ? AppTheme.expenseColor(context)
                  : AppTheme.incomeColor(context);

              final categoryColor = Color(
                int.parse(category.colorHex.replaceFirst('#', '0xFF')),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Dismissible(
                  key: Key(payment.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) =>
                      _showDeleteConfirmation(context, ref, payment),
                  onDismissed: (direction) {
                    ref
                        .read(plannedPaymentProvider.notifier)
                        .deletePlannedPayment(payment.id);
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 28),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseColor(context),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  child: PressableScale(
                    onTap: () {
                      HapticService.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddEditPlannedPaymentScreen(payment: payment),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.1),
                          width: 1,
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  IconUtils.getIcon(category.iconCodePoint),
                                  color: categoryColor,
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
                                          color: AppTheme.textLightColor(
                                            context,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          payment.frequency.name.toUpperCase(),
                                          style: TextStyle(
                                            color: AppTheme.textLightColor(
                                              context,
                                            ),
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
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.bolt_rounded,
                                                  size: 10,
                                                  color: AppTheme.primaryColor(
                                                    context,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'AUTO',
                                                  style: TextStyle(
                                                    color:
                                                        AppTheme.primaryColor(
                                                          context,
                                                        ),
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
                                "${isExpense ? '-' : '+'}${NumberFormat.currency(symbol: currency.symbol).format(payment.amount)}",
                                style: TextStyle(
                                  color: amountColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.5,
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
                                        'Next Payment',
                                        style: TextStyle(
                                          color: AppTheme.textLightColor(
                                            context,
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        DateFormat.yMMMd().format(
                                          payment.nextDate,
                                        ),
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
                                  _paySubscription(context, ref, payment);
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
                                  child: const Text(
                                    'Pay Now',
                                    style: TextStyle(
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
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: \$error')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor(context),
        onPressed: () {
          HapticService.light();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditPlannedPaymentScreen(),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
