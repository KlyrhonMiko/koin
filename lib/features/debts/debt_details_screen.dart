import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/add_edit_debt_screen.dart';
import 'package:koin/features/debts/widgets/add_purchase_sheet.dart';
import 'package:koin/features/debts/widgets/debt_purchase_card.dart';
import 'package:koin/features/debts/widgets/add_repayment_sheet.dart';

class DebtDetailsScreen extends ConsumerStatefulWidget {
  final String debtId;
  const DebtDetailsScreen({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends ConsumerState<DebtDetailsScreen> {
  bool _purchasesExpanded = true;
  int _visiblePurchases = 20;

  Future<void> _deleteRepayment(DebtRepayment repayment) async {
    await ref.read(debtsProvider.notifier).deleteRepayment(repayment);
  }

  void _addRepayment(
    BuildContext context,
    Debt debt, {
    bool isIncrease = false,
  }) {
    AddRepaymentSheet.show(context, debt: debt, isIncrease: isIncrease);
  }

  final KoinAsyncActionGuard _deleteGuard = KoinAsyncActionGuard();

  Future<void> _showDeleteConfirmation(Debt debt) => _deleteGuard.run(
    context,
    () => _showDeleteConfirmationImpl(debt),
    errorTitle: 'Could not delete this item',
  );

  Future<void> _showDeleteConfirmationImpl(Debt debt) async {
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Delete Credit/IOU?',
      description: 'Are you sure you want to delete this credit/IOU? This action cannot be undone and will delete all associated payment history.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.errorColor(context),
      icon: KoinIcons.trash,
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

  Future<void> _rememberPurchase(Debt debt, DebtItem item) async {
    if (!mounted || item.categoryId == null) return;
    await ref
        .read(categorySuggesterProvider)
        .recordFeedback(
          text: item.name,
          amount: item.amount,
          type: debt.type == DebtType.owedToMe
              ? TransactionType.income
              : TransactionType.expense,
          originAccountId: debt.accountId ?? '',
          destinationId: item.categoryId!,
        )
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsProvider);
    final repaymentsAsync = ref.watch(debtRepaymentsProvider(widget.debtId));
    final settings = ref.watch(settingsProvider);
    final currencyFormat = settings.currency.formatter;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: KoinContentWidth(
        maxWidth: 760,
        child: debtsAsync.when(
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
                      horizontal: KoinSpacing.screenInset,
                      vertical: 8,
                    ),
                    child: KoinPageHeader(
                      title: debt.type == DebtType.owedToMe
                          ? 'Money owed to you'
                          : 'Credit & IOU details',
                    ),
                  ),
                  // ── Body ──
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            KoinSpacing.screenInset,
                            8,
                            KoinSpacing.screenInset,
                            32,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMainCard(
                                  context,
                                  debt: debt,
                                  color: color,
                                  currencyFormat: currencyFormat,
                                ),
                                const Gap(24),
                                _buildQuickActions(context, debt, color),
                                if (debt.isPurchaseAccount ||
                                    debt.items.isNotEmpty) ...[
                                  const Gap(32),
                                  _buildItemsSection(
                                    context,
                                    debt,
                                    currencyFormat,
                                    color,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KoinSpacing.screenInset,
                          ),
                          sliver: _buildPaymentHistorySection(
                            context,
                            repaymentsAsync: repaymentsAsync,
                            currencyFormat: currencyFormat,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              KoinErrorState(onRetry: () => ref.invalidate(debtsProvider)),
        ),
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
    final cardColor = isSettled ? AppTheme.incomeColor(context) : color;

    return KoinSummaryCard(
          shapeStyle: SummaryShapeStyle.debtDetails,
          borderRadius: KoinShape.summary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cardColor, cardColor.withValues(alpha: 0.85)],
          ),
          glowColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                debt.personName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: KoinTypography.sectionTitle,
                  fontWeight: KoinTypography.headingWeight,
                  letterSpacing: KoinTypography.headingTracking,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Gap(12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedCounter(
                  value: remaining,
                  formatter: (v) => currencyFormat.format(v),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  style: KoinTypography.summaryAmountStyle,
                ),
              ),
              const Gap(8),
              Text(
                debt.isMonthlyPurchaseAccount && !debt.isSettled
                    ? '${currencyFormat.format(debt.upcomingPayment(decimalDigits: currencyFormat.decimalDigits ?? 2))} next bill · ${DateFormat.MMMd().format(debt.nextPaymentDate(decimalDigits: currencyFormat.decimalDigits ?? 2))}'
                    : debt.totalInstallments > 0
                    ? '${currencyFormat.format(debt.amount)} total · ${debt.totalInstallments} ${debt.frequency.label.toLowerCase()} payments'
                    : '${currencyFormat.format(debt.amount)} total',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: KoinTypography.small,
                  fontWeight: KoinTypography.supportingWeight,
                ),
              ),
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}% Repaid',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: KoinTypography.caption,
                            fontWeight: KoinTypography.labelWeight,
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(debt.amount - remaining)} paid',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: KoinTypography.caption,
                            fontWeight: KoinTypography.labelWeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(6),
                  // Progress Track
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .koinAnimate(
          context,
          autoPlay: !MediaQuery.disableAnimationsOf(context),
          onInit: KoinMotion.onInit(context),
        )
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.05, curve: Curves.easeOutCubic);
  }

  // ── Quick Actions ──
  Widget _buildQuickActions(BuildContext context, Debt debt, Color color) {
    final actions = <Widget>[
      _buildActionItem(
        context,
        icon: KoinIcons.plus,
        label: 'Payment',
        color: color,
        onTap: () => _addRepayment(context, debt),
      ),
      _buildActionItem(
        context,
        icon: KoinIcons.arrowUp,
        label: 'Increase',
        color: color,
        onTap: () => _addRepayment(context, debt, isIncrease: true),
      ),
      _buildActionItem(
        context,
        icon: KoinIcons.pencilSimple,
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
        icon: KoinIcons.trash,
        label: 'Delete',
        color: AppTheme.expenseColor(context),
        onTap: () => _showDeleteConfirmation(debt),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(12) > 18
            ? 2
            : 4;
        return Wrap(
          runSpacing: 20,
          children: [
            for (final action in actions)
              SizedBox(width: constraints.maxWidth / columns, child: action),
          ],
        );
      },
    ).koinEntrance(context);
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return KoinQuickAction(
      icon: icon,
      label: label,
      color: color,
      onPressed: onTap,
      elevated: true,
    );
  }

  Widget _buildItemsSection(
    BuildContext context,
    Debt debt,
    NumberFormat currencyFormat,
    Color color,
  ) {
    final items = debt.items;

    // Calculate paid amount per item by generating all installments
    final List<_ItemInstallment> installments = [];
    for (var item in items) {
      if (item.totalInstallments > 0) {
        DateTime nextDate = item.firstPaymentDate;
        for (int i = 0; i < item.totalInstallments; i++) {
          installments.add(
            _ItemInstallment(
              item.id,
              nextDate,
              item.installmentAmountAt(
                i,
                decimalDigits: currencyFormat.decimalDigits ?? 2,
              ),
            ),
          );
          nextDate = debt.isMonthlyPurchaseAccount
              ? debt.monthlyBillDate(nextDate.year, nextDate.month + 1)
              : _advanceDate(nextDate, debt.frequency, item.firstPaymentDate);
        }
      } else {
        installments.add(
          _ItemInstallment(item.id, item.firstPaymentDate, item.amount),
        );
      }
    }

    final Map<DateTime, List<_ItemInstallment>> groupedInstallments = {};
    for (var inst in installments) {
      final dateKey = DateTime(
        inst.dueDate.year,
        inst.dueDate.month,
        inst.dueDate.day,
      );
      groupedInstallments.putIfAbsent(dateKey, () => []).add(inst);
    }

    final sortedDates = groupedInstallments.keys.toList()..sort();

    double remainingPaid = debt.currentAmount;
    final Map<String, double> paidAmounts = {
      for (var item in items) item.id: 0.0,
    };

    for (var date in sortedDates) {
      if (remainingPaid <= 0) break;
      final group = groupedInstallments[date]!;
      final double totalGroupAmount = group.fold(
        0.0,
        (sum, inst) => sum + inst.amount,
      );

      if (remainingPaid >= totalGroupAmount) {
        for (var inst in group) {
          paidAmounts[inst.itemId] =
              (paidAmounts[inst.itemId] ?? 0.0) + inst.amount;
        }
        remainingPaid -= totalGroupAmount;
      } else {
        for (var inst in group) {
          final double ratio = inst.amount / totalGroupAmount;
          paidAmounts[inst.itemId] =
              (paidAmounts[inst.itemId] ?? 0.0) + (remainingPaid * ratio);
        }
        remainingPaid = 0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _purchasesExpanded,
          child: InkWell(
            key: const Key('toggle_purchases'),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticService.light();
              setState(() => _purchasesExpanded = !_purchasesExpanded);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: DebtPurchaseSectionHeader(
                      count: items.length,
                      color: color,
                    ),
                  ),
                  Icon(
                    _purchasesExpanded
                        ? KoinIcons.caretUp
                        : KoinIcons.caretDown,
                    color: AppTheme.textLightColor(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_purchasesExpanded) const Gap(16),
        // Item tiles
        if (_purchasesExpanded)
          ...items.take(_visiblePurchases).toList().asMap().entries.map((
            entry,
          ) {
            final item = entry.value;
            return Padding(
              key: ValueKey('purchase_${item.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: SwipeToDeleteTile(
                key: Key('dismiss_purchase_${item.id}'),
                borderRadius: BorderRadius.circular(18),
                fillRoundedCorners: true,
                backgroundColor: AppTheme.errorColor(context),
                icon: KoinIcons.trash,
                confirmTitle: 'Delete Purchase?',
                confirmDescription:
                    'Delete "${item.name}"? This will update the credit total. This action cannot be undone.',
                onDelete: () async {
                  HapticService.heavy();
                  await ref
                      .read(debtsProvider.notifier)
                      .removeDebtItem(debt, item);
                },
                child: PressableScale(
                  enableHaptic: false,
                  onTap: () async {
                    HapticService.light();
                    final categories = ref.read(categoriesProvider).value ?? [];
                    var categoryConfirmed = false;
                    final updatedItem = await showAddPurchaseSheet(
                      context: context,
                      debtType: debt.type,
                      primaryColor: color,
                      categories: categories,
                      defaultDate: debt.isMonthlyPurchaseAccount
                          ? debt.nextPurchaseBillDate
                          : DateTime.now(),
                      monthlyBillingDay: debt.isMonthlyPurchaseAccount
                          ? debt.startDate.day
                          : null,
                      existingItem: item,
                      onSave: (draft) => ref
                          .read(debtsProvider.notifier)
                          .saveDebtItem(debt, draft),
                      suggester: ref.read(categorySuggesterProvider),
                      onCategoryConfirmed: (_) => categoryConfirmed = true,
                    );

                    if (updatedItem != null) {
                      if (categoryConfirmed) {
                        await _rememberPurchase(debt, updatedItem);
                      }

                      if (context.mounted) {
                        KoinSnackBar.success(context, 'Purchase Updated');
                      }
                    }
                  },
                  child: DebtPurchaseCard(
                    item: item,
                    categories: ref.watch(categoriesProvider).value ?? [],
                    currencyFormat: currencyFormat,
                    color: color,
                    paidAmount: paidAmounts[item.id] ?? 0.0,
                  ),
                ),
              ),
            );
          }),
        if (_purchasesExpanded && items.length > _visiblePurchases)
          TextButton(
            onPressed: () => setState(() => _visiblePurchases += 20),
            child: Text(
              'Show more purchases (${items.length - _visiblePurchases} remaining)',
            ),
          ),
        if (_purchasesExpanded && debt.isPurchaseAccount) ...[
          const Gap(6),
          PressableScale(
            enableHaptic: false,
            onTap: () async {
              HapticService.light();
              final categories = ref.read(categoriesProvider).value ?? [];
              var categoryConfirmed = false;
              final newItem = await showAddPurchaseSheet(
                context: context,
                debtType: debt.type,
                primaryColor: color,
                categories: categories,
                defaultDate: debt.isMonthlyPurchaseAccount
                    ? debt.nextPurchaseBillDate
                    : DateTime.now(),
                monthlyBillingDay: debt.isMonthlyPurchaseAccount
                    ? debt.startDate.day
                    : null,
                suggester: ref.read(categorySuggesterProvider),
                onSave: (draft) => ref
                    .read(debtsProvider.notifier)
                    .saveDebtItem(debt, draft.copyWith(debtId: debt.id)),
                onCategoryConfirmed: (_) => categoryConfirmed = true,
              );

              if (newItem != null) {
                final newDebtItem = newItem.copyWith(debtId: debt.id);
                if (categoryConfirmed) {
                  await _rememberPurchase(debt, newDebtItem);
                }

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
                  Icon(KoinIcons.plusCircle, color: color, size: 20),
                  const Gap(8),
                  Flexible(
                    child: Text(
                      'Add Purchase',
                      style: TextStyle(
                        color: color,
                        fontWeight: KoinTypography.titleWeight,
                        fontSize: KoinTypography.body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentHistorySection(
    BuildContext context, {
    required AsyncValue<List<DebtRepayment>> repaymentsAsync,
    required NumberFormat currencyFormat,
    required Color color,
  }) {
    final repayments = (repaymentsAsync.value ?? <DebtRepayment>[]).toList();
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: const KoinSectionHeader(title: 'Credit Activity'),
          ),
        ),
        repaymentsAsync.when(
          data: (_) {
            if (repayments.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: KoinActivityEmptyState(
                  title: 'No payments yet',
                  subtitle: 'Tap "Payment" to record a repayment',
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList.builder(
                key: const ValueKey('repayments_column'),
                itemCount: repayments.length,
                itemBuilder: (context, index) => _buildRepaymentTile(
                  context,
                  repayment: repayments[index],
                  currencyFormat: currencyFormat,
                  color: color,
                  isFirst: index == 0,
                ),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SliverToBoxAdapter(
            child: KoinErrorState(
              onRetry: () =>
                  ref.invalidate(debtRepaymentsProvider(widget.debtId)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepaymentTile(
    BuildContext context, {
    required DebtRepayment repayment,
    required NumberFormat currencyFormat,
    required Color color,
    required bool isFirst,
  }) {
    final amount = Text(
      currencyFormat.format(repayment.amount),
      textAlign: TextAlign.end,
      style: TextStyle(
        color: color,
        fontSize: KoinTypography.itemAmount,
        fontWeight: KoinTypography.titleWeight,
        letterSpacing: KoinTypography.itemTracking,
      ),
    );
    return Column(
      key: ValueKey('repayment_row_${repayment.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirst) Divider(height: 1, color: AppTheme.dividerColor(context)),
        SwipeToDeleteTile(
          key: Key('dismiss_repayment_${repayment.id}'),
          margin: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: AppTheme.errorColor(context).withValues(alpha: 0.15),
          iconColor: AppTheme.errorColor(context),
          icon: KoinIcons.trash,
          confirmTitle: 'Delete Payment?',
          confirmDescription:
              'Are you sure you want to delete this payment of ${currencyFormat.format(repayment.amount)}? This action cannot be undone.',
          confirmLabel: 'Delete Payment',
          onDelete: () => _deleteRepayment(repayment),
          failureTitle: 'Could not delete payment',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: KoinActivityRow(
              leading: KoinIconBadge(
                icon: repayment.isIncrease
                    ? KoinIcons.arrowUpRight
                    : KoinIcons.arrowDownLeft,
                color: color,
              ),
              title: repayment.note?.isNotEmpty == true
                  ? repayment.note!
                  : repayment.isIncrease
                  ? 'Increased Credit'
                  : 'Payment',
              stackedTitleMaxLines: null,
              amount: amount,
              subtitle: Text(
                _formatActivityDate(repayment.date),
                style: TextStyle(
                  color: AppTheme.textLightColor(context),
                  fontSize: KoinTypography.small,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatActivityDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final formatted = date.year == now.year
        ? DateFormat.MMMd().format(date)
        : DateFormat.yMMMd().format(date);
    if (difference.isNegative || difference.inDays >= 7) return formatted;
    final relative = difference.inMinutes < 1
        ? 'Just now'
        : difference.inMinutes < 60
        ? '${difference.inMinutes}m ago'
        : difference.inHours < 24
        ? '${difference.inHours}h ago'
        : difference.inDays == 1
        ? 'Yesterday'
        : '${difference.inDays}d ago';
    return '$formatted · $relative';
  }
}

DateTime _advanceDate(
  DateTime date,
  InstallmentFrequency frequency,
  DateTime originalDate,
) {
  switch (frequency) {
    case InstallmentFrequency.weekly:
      return date.add(const Duration(days: 7));
    case InstallmentFrequency.biweekly:
      return date.add(const Duration(days: 14));
    case InstallmentFrequency.monthly:
      int newYear = date.year;
      int newMonth = date.month + 1;
      if (newMonth > 12) {
        newYear += (newMonth - 1) ~/ 12;
        newMonth = ((newMonth - 1) % 12) + 1;
      }
      final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
      final newDay = originalDate.day > daysInNewMonth
          ? daysInNewMonth
          : originalDate.day;
      return DateTime(newYear, newMonth, newDay);
    case InstallmentFrequency.yearly:
      final isLeapDay = originalDate.month == 2 && originalDate.day == 29;
      final targetYear = date.year + 1;
      final isTargetLeapYear =
          (targetYear % 4 == 0 && targetYear % 100 != 0) ||
          (targetYear % 400 == 0);
      final newDay = (isLeapDay && !isTargetLeapYear) ? 28 : originalDate.day;
      return DateTime(targetYear, originalDate.month, newDay);
  }
}

class _ItemInstallment {
  final String itemId;
  final DateTime dueDate;
  final double amount;

  _ItemInstallment(this.itemId, this.dueDate, this.amount);
}
