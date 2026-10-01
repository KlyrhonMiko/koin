import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/cashflow/cashflow.dart';
import 'package:koin/features/dashboard/widgets/upcoming_entry_tile.dart';

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

    final isExpense = payment.type == TransactionType.expense;

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
        isExpense ? 'Payment processed' : 'Income processed',
        subtitle: isExpense
            ? 'Your planned payment has been completed'
            : 'Your recurring income has been completed',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(upcomingTimelineProvider);
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
            child: timeline.isEmpty
                ? _buildEmptyUpcoming(context)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    physics: const BouncingScrollPhysics(),
                    itemCount: timeline.length,
                    itemBuilder: (context, index) {
                      final entry = timeline.entries[index];
                      final category = categories
                          .where((c) => c.id == entry.categoryId)
                          .firstOrNull;

                      return UpcomingEntryTile(
                        entry: entry,
                        currency: currency,
                        category: category,
                        onPayPayment: (payment) =>
                            _paySubscription(context, ref, payment),
                      )
                          .animate()
                          .fade(delay: (index * 40).ms)
                          .slideY(begin: 0.08);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUpcoming(BuildContext context) {
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
                  color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
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
                    color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
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
}
