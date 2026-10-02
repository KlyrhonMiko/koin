import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/add_edit_debt_screen.dart';
import 'package:koin/features/debts/widgets/add_purchase_sheet.dart';
import 'package:koin/features/debts/widgets/add_repayment_sheet.dart';

class DebtDetailsScreen extends ConsumerStatefulWidget {
  final String debtId;
  const DebtDetailsScreen({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends ConsumerState<DebtDetailsScreen> {
  void _addRepayment(
    BuildContext context,
    Debt debt, {
    bool isIncrease = false,
  }) {
    AddRepaymentSheet.show(context, debt: debt, isIncrease: isIncrease);
  }

  Future<void> _showDeleteConfirmation(Debt debt) async {
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Delete Credit/IOU?',
      description:
          'Are you sure you want to delete this credit/IOU? This action cannot be undone and will delete all associated payment history.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.errorColor(context),
      icon: Icons.delete_outline_rounded,
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      HapticService.heavy();
      await ref.read(debtsProvider.notifier).deleteDebt(debt.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsProvider);
    final repaymentsAsync = ref.watch(debtRepaymentsProvider(widget.debtId));
    final settings = ref.watch(settingsProvider);
    final currencyFormat = NumberFormat.simpleCurrency(
      name: settings.currency.code,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: debtsAsync.when(
        data: (debts) {
          final debt = debts.cast<Debt?>().firstWhere(
            (d) => d?.id == widget.debtId,
            orElse: () => null,
          );
          if (debt == null) {
            return const Center(child: Text('Credit/IOU not found'));
          }

          final color = debt.type == DebtType.owedToMe
              ? AppTheme.incomeColor(context)
              : AppTheme.expenseColor(context);

          return SafeArea(
            child: Column(
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const KoinBackButton(),
                      const Gap(16),
                      Expanded(
                        child: Text(
                          'Credit Details',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.textColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Removed Edit and Delete from AppBar to put them in Quick Actions
                    ],
                  ),
                ),
                // ── Body ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Main Card ──
                        _buildMainCard(
                          context,
                          debt: debt,
                          color: color,
                          currencyFormat: currencyFormat,
                        ),
                        const Gap(24),
                        // ── Quick Actions ──
                        _buildQuickActions(context, debt, color),
                        const Gap(32),

                        _buildItemsSection(
                          context,
                          debt,
                          currencyFormat,
                          color,
                        ),
                        const Gap(32),

                        // ── Payment History ──
                        _buildPaymentHistorySection(
                          context,
                          repaymentsAsync: repaymentsAsync,
                          currencyFormat: currencyFormat,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: \$e')),
      ),
    );
  }

  // ── Main Card ──
  Widget _buildMainCard(
    BuildContext context, {
    required Debt debt,
    required Color color,
    required NumberFormat currencyFormat,
  }) {
    final progress = debt.progress;
    final isSettled = debt.isSettled;
    final remaining = debt.remainingAmount;

    return KoinSummaryCard(
          shapeStyle: SummaryShapeStyle.debtDetails,
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.85)],
          ),
          glowColor: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    // Person Name & Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            debt.personName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isSettled
                                ? 'SETTLED'
                                : debt.type == DebtType.owedToMe
                                ? 'OWES YOU'
                                : 'YOU OWE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (debt.totalInstallments > 0) ...[
                      const Gap(4),
                      Text(
                        '${debt.totalInstallments} ${debt.frequency.name} payments',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const Gap(24),

                    // Total Debt Amount
                    AnimatedCounter(
                      value: debt.amount,
                      formatter: (v) => currencyFormat.format(v),
                      duration: const Duration(milliseconds: 1400),
                      curve: Curves.easeOutCubic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                    ),

                    const Gap(28),

                    // Progress Bar Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(progress * 100).toStringAsFixed(1)}% Repaid',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${currencyFormat.format(remaining)} left',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Gap(8),
                        // Progress Track
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Stack(
                            children: [
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, curve: Curves.easeOutCubic);
  }

  // ── Quick Actions ──
  Widget _buildQuickActions(BuildContext context, Debt debt, Color color) {
    return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionItem(
              context,
              icon: Icons.add_rounded,
              label: 'Payment',
              color: color,
              onTap: () => _addRepayment(context, debt),
            ),
            _buildActionItem(
              context,
              icon: Icons.arrow_upward_rounded,
              label: 'Increase',
              color: color,
              onTap: () => _addRepayment(context, debt, isIncrease: true),
            ),
            _buildActionItem(
              context,
              icon: Icons.edit_rounded,
              label: 'Edit',
              color: AppTheme.textLightColor(context),
              onTap: () {
                HapticService.light();
                Navigator.push(
                  context,
                  SlideUpRoute(page: AddEditDebtScreen(debt: debt)),
                );
              },
            ),
            _buildActionItem(
              context,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppTheme.expenseColor(context),
              onTap: () => _showDeleteConfirmation(debt),
            ),
          ],
        )
        .animate()
        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.95, 0.95),
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      enableHaptic: false,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Gap(8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textLightColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(
    BuildContext context,
    Debt debt,
    NumberFormat currencyFormat,
    Color color,
  ) {
    final items = debt.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              'Sub-Plans / Purchases',
              style: TextStyle(
                color: AppTheme.textColor(context),
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const Gap(10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const Gap(16),
        // Item tiles
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return PressableScale(
                onTap: () async {
                  HapticService.light();
                  final categories = ref.read(categoriesProvider).value ?? [];
                  final updatedItem = await showAddPurchaseSheet(
                    context: context,
                    debtType: debt.type,
                    primaryColor: color,
                    categories: categories,
                    defaultDate: DateTime.now(),
                    existingItem: item,
                    suggester: ref.read(categorySuggesterProvider),
                  );

                  if (updatedItem != null) {
                    await ref
                        .read(debtsProvider.notifier)
                        .saveDebtItem(debt, updatedItem);

                    if (context.mounted) {
                      KoinSnackBar.success(context, 'Purchase Updated');
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.dividerColor(
                        context,
                      ).withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final categories =
                              ref.read(categoriesProvider).value ?? [];
                          final category = categories
                              .cast<TransactionCategory?>()
                              .firstWhere(
                                (c) => c?.id == item.categoryId,
                                orElse: () => null,
                              );

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (category?.color ?? color).withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              category != null
                                  ? IconUtils.getIcon(category.iconCodePoint)
                                  : Icons.shopping_bag_outlined,
                              color: category?.color ?? color,
                              size: 20,
                            ),
                          );
                        },
                      ),
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                color: AppTheme.textColor(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Gap(4),
                            Text(
                              '${item.totalInstallments} payments • Starts ${DateFormat.MMMd().format(item.firstPaymentDate)}',
                              style: TextStyle(
                                color: AppTheme.textLightColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      Text(
                        currencyFormat.format(item.amount),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: Duration(milliseconds: 100 + 50 * index))
              .slideY(begin: 0.1);
        }),
        const Gap(6),
        PressableScale(
          onTap: () async {
            HapticService.light();
            final categories = ref.read(categoriesProvider).value ?? [];
            final newItem = await showAddPurchaseSheet(
              context: context,
              debtType: debt.type,
              primaryColor: color,
              categories: categories,
              defaultDate: DateTime.now(),
              suggester: ref.read(categorySuggesterProvider),
            );

            if (newItem != null) {
              final newDebtItem = newItem.copyWith(debtId: debt.id);
              await ref
                  .read(debtsProvider.notifier)
                  .saveDebtItem(debt, newDebtItem);

              if (context.mounted) {
                KoinSnackBar.success(context, 'Purchase Added');
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded, color: color, size: 20),
                const Gap(8),
                Text(
                  'Add Purchase / Sub-Plan',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHistorySection(
    BuildContext context, {
    required AsyncValue<List<DebtRepayment>> repaymentsAsync,
    required NumberFormat currencyFormat,
    required Color color,
  }) {
    return repaymentsAsync.when(
      data: (repayments) {
        if (repayments.isEmpty) {
          return Center(
            child:
                Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Gap(24),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.06),
                                blurRadius: 30,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 36,
                            color: AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        const Gap(16),
                        Text(
                          'No payments yet',
                          style: TextStyle(
                            color: AppTheme.textColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Gap(6),
                        Text(
                          'Tap "Log Payment" to record a repayment',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                    .animate()
                    .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      duration: 250.ms,
                      curve: Curves.easeOutCubic,
                    ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Text(
                  'Credit Activity',
                  style: TextStyle(
                    color: AppTheme.textColor(context),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const Gap(10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${repayments.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(16),
            // Payment tiles with timeline
            ...repayments.asMap().entries.map((entry) {
              final index = entry.key;
              final r = entry.value;
              final isLast = index == repayments.length - 1;
              return _buildRepaymentTile(
                context,
                repayment: r,
                currencyFormat: currencyFormat,
                color: color,
                tileIndex: index,
                paymentNumber: repayments.length - index,
                isLast: isLast,
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: \$e')),
    );
  }

  Widget _buildRepaymentTile(
    BuildContext context, {
    required DebtRepayment repayment,
    required NumberFormat currencyFormat,
    required Color color,
    required int tileIndex,
    required int paymentNumber,
    required bool isLast,
  }) {
    return SwipeToDeleteTile(
      key: Key(repayment.id),
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: BorderRadius.circular(18),
      confirmTitle: 'Delete Payment?',
      confirmDescription:
          'Are you sure you want to delete this payment of ${currencyFormat.format(repayment.amount)}? This action cannot be undone.',
      confirmLabel: 'Delete Payment',
      onDelete: () {
        ref.read(debtsProvider.notifier).deleteRepayment(repayment);
      },
      child:
          IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline connector
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: repayment.isIncrease
                                  ? Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 14,
                                      color: color,
                                    )
                                  : Text(
                                      '#$paymentNumber',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.dividerColor(
                                    context,
                                  ).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    // Payment card
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.dividerColor(
                              context,
                            ).withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    repayment.isIncrease
                                        ? (repayment.note?.isNotEmpty == true
                                              ? repayment.note!
                                              : 'Increased Credit')
                                        : (repayment.note?.isNotEmpty == true
                                              ? repayment.note!
                                              : 'Payment'),
                                    style: TextStyle(
                                      color: AppTheme.textColor(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const Gap(3),
                                  Text(
                                    DateFormat.yMMMd().format(repayment.date),
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
                              currencyFormat.format(repayment.amount),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .slideX(
                begin: 0.1,
                delay: Duration(milliseconds: 60 * tileIndex),
                duration: 300.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeIn(
                delay: Duration(milliseconds: 60 * tileIndex),
                duration: 300.ms,
              ),
    );
  }
}
