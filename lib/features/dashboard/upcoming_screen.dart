import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/cashflow/cashflow.dart';
import 'package:koin/features/dashboard/widgets/upcoming_entry_tile.dart';

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

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
            padding: EdgeInsets.fromLTRB(
              KoinSpacing.screenInset,
              topPadding + 16,
              KoinSpacing.screenInset,
              16,
            ),
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
                    fontSize: KoinTypography.screenTitle,
                    fontWeight: KoinTypography.headingWeight,
                    color: AppTheme.textColor(context),
                    letterSpacing: KoinTypography.headingTracking,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: timeline.isEmpty
                ? _buildEmptyUpcoming(context)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      KoinSpacing.screenInset,
                      24,
                      KoinSpacing.screenInset,
                      120,
                    ),
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
                                PaymentConfirmationSheet.confirmAndProcess(
                                  context: context,
                                  ref: ref,
                                  payment: payment,
                                ),
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

  Widget _buildEmptyUpcoming(BuildContext context) => KoinEmptyState(
    fullScreen: true,
    icon: Icons.event_repeat_rounded,
    title: 'No upcoming payments',
    subtitle: 'Add your first subscription to see it here',
    action: TextButton(
      onPressed: () {
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
      child: const Text('Add subscription'),
    ),
  );
}
