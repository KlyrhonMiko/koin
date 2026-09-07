import 'package:flutter/material.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/features/recurring_incomes/add_edit_recurring_income_screen.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/widgets/payment_confirmation_sheet.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RecurringIncomesTab extends ConsumerWidget {
  const RecurringIncomesTab({super.key});

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
      note: '${payment.title} (Recurring Income)',
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
        'Income processed',
        subtitle: 'Your recurring income has been completed',
      );
    }
  }

  Widget _buildFullEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
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
                          icon,
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
                        title,
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 300.ms, duration: 400.ms)
                      .fadeIn(),
                  const SizedBox(height: 8),
                  Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 400.ms, duration: 400.ms)
                      .fadeIn(),
                  const SizedBox(height: 36),
                  SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppTheme.primaryGradient(context),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticService.medium();
                              onTap();
                            },
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                            ),
                            label: Text(
                              buttonLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 500.ms, duration: 400.ms)
                      .fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddIncomeButton(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticService.medium();
        Navigator.push(
          context,
          SlideUpRoute(page: const AddEditRecurringIncomeScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, top: 4),
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
            const SizedBox(width: 10),
            Text(
              'Add New Income',
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

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    PlannedPayment payment,
  ) async {
    return await ConfirmationSheet.show(
      context: context,
      title: 'Delete Recurring Income?',
      description:
          'Are you sure you want to delete "${payment.title}"? This action cannot be undone.',
      confirmLabel: 'Delete Income',
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

    return paymentsAsync.when(
        data: (payments) {
          final incomes = payments.where((p) => p.type == TransactionType.income).toList();
          if (incomes.isEmpty) {
            return _buildFullEmptyState(
              context,
              icon: Icons.payments_rounded,
              title: 'No recurring incomes',
              subtitle: 'Add recurring incomes to track\nyour future earnings',
              buttonLabel: 'Add Your First Income',
              onTap: () {
                Navigator.push(
                  context,
                  SlideUpRoute(page: const AddEditRecurringIncomeScreen()),
                );
              },
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: incomes.length + 1,
            itemBuilder: (context, index) {
              if (index == incomes.length) {
                return _buildAddIncomeButton(context);
              }
              final payment = incomes[index];
              final category = categories.firstWhere(
                (c) => c.id == payment.categoryId,
                orElse: () => categories.first,
              );

              final amountColor = AppTheme.incomeColor(context);

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
                              AddEditRecurringIncomeScreen(payment: payment),
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
                                "+${NumberFormat.currency(symbol: currency.symbol).format(payment.amount)}",
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
                                        'Next Income Date',
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
                                    'Collect Now',
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
      );
  }
}
