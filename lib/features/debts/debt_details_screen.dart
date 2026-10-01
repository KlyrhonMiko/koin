import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/add_edit_debt_screen.dart';
import 'package:koin/features/debts/widgets/add_purchase_sheet.dart';
import 'package:uuid/uuid.dart';

class DebtDetailsScreen extends ConsumerStatefulWidget {
  final String debtId;
  const DebtDetailsScreen({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends ConsumerState<DebtDetailsScreen> {
  void _addRepayment(BuildContext context, Debt debt, {bool isIncrease = false}) {
    HapticService.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddRepaymentSheet(debt: debt, isIncrease: isIncrease),
    );
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

          final progress = debt.progress;
          final isSettled = debt.isSettled;
          final remaining = debt.remainingAmount;
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
                          progress: progress,
                          isSettled: isSettled,
                          remaining: remaining,
                          color: color,
                          currencyFormat: currencyFormat,
                        ),
                        const Gap(24),
                        // ── Quick Actions ──
                        _buildQuickActions(context, debt, color),
                        const Gap(32),

                        _buildItemsSection(context, debt, currencyFormat, color),
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
    required double progress,
    required bool isSettled,
    required double remaining,
    required Color color,
    required NumberFormat currencyFormat,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background circle decorations
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
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
        .animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic);
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
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
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
              );
              
              if (updatedItem != null) {
                await ref.read(debtsProvider.notifier).updateDebtItem(item, updatedItem);
                
                final newItems = debt.items.map((i) => i.id == item.id ? updatedItem : i).toList();
                final newAmount = newItems.fold(0.0, (sum, i) => sum + i.amount);
                
                final updatedDebt = debt.copyWith(
                  amount: newAmount,
                  items: newItems,
                );
                await ref.read(debtsProvider.notifier).updateDebt(updatedDebt);
                
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
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
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
                      final categories = ref.read(categoriesProvider).value ?? [];
                      final category = categories.cast<TransactionCategory?>().firstWhere(
                        (c) => c?.id == item.categoryId,
                        orElse: () => null,
                      );
                      
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (category?.color ?? color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          category != null ? IconUtils.getIcon(category.iconCodePoint) : Icons.shopping_bag_outlined, 
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
          ).animate().fadeIn(delay: Duration(milliseconds: 100 + 50 * index)).slideY(begin: 0.1);
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
            );
            
            if (newItem != null) {
              final newDebtItem = newItem.copyWith(debtId: debt.id);
              await ref.read(debtsProvider.notifier).addDebtItem(newDebtItem);
              
              final updatedDebt = debt.copyWith(
                amount: debt.amount + newDebtItem.amount,
                items: [...debt.items, newDebtItem],
              );
              await ref.read(debtsProvider.notifier).updateDebt(updatedDebt);
              
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
                Text('Add Purchase / Sub-Plan', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
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
                    .animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
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

// ──────────────────────────────────────────────────────────────
//  Premium Log Payment Bottom Sheet
// ──────────────────────────────────────────────────────────────

class AddRepaymentSheet extends ConsumerStatefulWidget {
  final Debt debt;
  final bool isIncrease;
  const AddRepaymentSheet({super.key, required this.debt, this.isIncrease = false});

  @override
  ConsumerState<AddRepaymentSheet> createState() => AddRepaymentSheetState();
}

class AddRepaymentSheetState extends ConsumerState<AddRepaymentSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _noteFocusNode = FocusNode();
  String? _selectedAccountId;
  bool _accountInitialized = false;
  String _currentExpression = '';

  @override
  void initState() {
    super.initState();
    if (!widget.isIncrease && widget.debt.totalInstallments > 0) {
      final payment = widget.debt.upcomingPaymentAmount;
      var paymentStr = payment.toStringAsFixed(2);
      if (paymentStr.endsWith('.00')) {
        paymentStr = paymentStr.substring(0, paymentStr.length - 3);
      }
      _amountController.text = paymentStr;
    }
    _currentExpression = _amountController.text;
    _noteFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final accounts = ref.watch(accountProvider).value ?? [];
    final color = widget.debt.type == DebtType.owedToMe
        ? AppTheme.incomeColor(context)
        : AppTheme.expenseColor(context);

    if (!widget.isIncrease && !_accountInitialized && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
      _accountInitialized = true;
    }

    final selectedAccount = _selectedAccountId != null
        ? accounts.cast<Account?>().firstWhere(
            (a) => a?.id == _selectedAccountId,
            orElse: () => null,
          )
        : null;

    final hasAmount =
        _currentExpression.isNotEmpty && _currentExpression != '0';

    // Account is required whenever logging a real payment — money either
    // leaves your account (I owe) or arrives in your account (owed to me)
    final isAccountRequired = !widget.isIncrease;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          0,
          16,
          0,
          _noteFocusNode.hasFocus ? (MediaQuery.of(context).padding.bottom + 24) : 0,
        ),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Minimal Handle ──
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(24),

            // ── Title ──
            Text(
              widget.isIncrease ? 'Increase Credit' : 'Log Payment',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.5,
              ),
            ),
            const Gap(32),

            // ── Beautiful Amount Input ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    settings.currency.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Gap(4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${settings.currency.symbol} ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.4),
                        ),
                      ),
                      Text(
                        _currentExpression.isEmpty ? '0' : _currentExpression,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: hasAmount
                              ? color
                              : color.withValues(alpha: 0.3),
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  if (_currentExpression.contains(RegExp(r'[+\-*/]')))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '= ${settings.currency.symbol}${_amountController.text}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  const Gap(12),
                  Container(
                    width: 48,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: color.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),
            const Gap(32),

            // ── Soft Fields (No harsh borders/shadows) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  SelectionTile(
                    asCard: false,
                    fallbackIcon: Icons.account_balance_wallet_rounded,
                    label: isAccountRequired ? 'Account' : 'Account (Optional)',
                    selectedName: selectedAccount?.name,
                    selectedColor: selectedAccount?.color,
                    selectedIconCodePoint: selectedAccount?.iconCodePoint,
                    selectedLogoAsset: selectedAccount?.logoAsset,
                    placeholder: isAccountRequired
                        ? 'Select Account'
                        : 'None (Balance only)',
                    onTap: () => _openAccountPicker(context, accounts),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                    indent: 64,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLightColor(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.sticky_note_2_rounded,
                            size: 18,
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            focusNode: _noteFocusNode,
                            onTap: () => HapticService.light(),
                            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: AppTheme.textColor(context),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a note...',
                              hintStyle: TextStyle(
                                color: AppTheme.textLightColor(context).withValues(alpha: 0.4),
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),

            if (!_noteFocusNode.hasFocus) ...[
              const Gap(16),
              NumPad(
                compact: true,
                initialValue: _currentExpression,
                onValueChanged: (expression, result) {
                  setState(() {
                    _currentExpression = expression;
                    _amountController.text = result;
                  });
                },
                onDone: _submit,
              ),
            ],
            
            if (_noteFocusNode.hasFocus) ...[
              const Gap(32),
              // ── Confirm button (Solid, crisp) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.isIncrease ? 'Confirm Increase' : 'Confirm Payment',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    HapticService.medium();
    final amtStr = _amountController.text.replaceAll(',', '');
    if (amtStr.isEmpty) return;
    final amt = double.tryParse(amtStr) ?? 0.0;
    if (amt <= 0) return;
    
    final isAccountRequired = !widget.isIncrease;
    final hasAccount = _selectedAccountId != null;
    
    if (isAccountRequired && !hasAccount) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Account Required',
        subtitle: 'Select an account to record this payment',
      );
      return;
    }

    final accounts = ref.read(accountProvider).value ?? [];
    final selectedAccount = _selectedAccountId != null
        ? accounts.cast<Account?>().firstWhere(
            (a) => a?.id == _selectedAccountId,
            orElse: () => null,
          )
        : null;

    final repayment = DebtRepayment(
      id: const Uuid().v4(),
      debtId: widget.debt.id,
      amount: amt,
      date: DateTime.now(),
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      accountId: _selectedAccountId,
      isIncrease: widget.isIncrease,
    );

    await ref.read(debtsProvider.notifier).addRepayment(repayment);

    if (repayment.accountId != null) {
      final isExpense = widget.isIncrease 
          ? widget.debt.type == DebtType.owedToMe
          : widget.debt.type == DebtType.iOwe;

      final transaction = AppTransaction(
        id: const Uuid().v4(),
        amount: repayment.amount,
        date: repayment.date,
        type: isExpense ? TransactionType.expense : TransactionType.income,
        categoryId: widget.debt.categoryId ?? (isExpense ? 'cat_others' : 'cat_others_inc'),
        accountId: repayment.accountId!,
        note: widget.isIncrease
            ? 'Increased Credit: ${widget.debt.personName}${repayment.note != null ? ' - ${repayment.note}' : ''}'
            : 'Credit Payment: ${widget.debt.personName}${repayment.note != null ? ' - ${repayment.note}' : ''}',
      );

      await ref.read(transactionProvider.notifier).addTransaction(
        transaction.copyWith(debtRepaymentId: repayment.id),
      );
    }

    if (!mounted) return;
    
    KoinSnackBar.success(
      context,
      widget.isIncrease ? 'Credit Increased' : 'Payment Logged',
      subtitle: 'Transaction added to ${selectedAccount?.name ?? 'Account'}',
    );
    Navigator.pop(context);
  }

  Future<void> _openAccountPicker(
    BuildContext context,
    List<Account> accounts,
  ) async {
    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _selectedAccountId,
      title: 'Account',
      subtitle: widget.isIncrease ? 'Which account was used?' : 'Choose the account for this payment',
      allowNone: widget.isIncrease,
      noneLabel: 'No Account (Balance only)',
      accountsOverride: accounts,
    );
    if (id != null && mounted) {
      setState(() => _selectedAccountId = id.isEmpty ? null : id);
    }
  }
}
