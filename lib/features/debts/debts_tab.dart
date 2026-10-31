import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/debts.dart';

class DebtsTab extends ConsumerWidget {
  final String? animationSessionKey;
  final bool showEntranceAnimations;

  const DebtsTab({
    super.key,
    this.animationSessionKey,
    this.showEntranceAnimations = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);
    final summary = ref.watch(debtSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final fmt = currency.formatter;

    return debtsAsync.when(
      data: (debts) {
        if (debts.isEmpty) {
          return KoinEmptyState.sliver(
            icon: KoinIcons.handshake,
            title: 'No credit or IOUs',
            subtitle:
                'Track BNPL, credit cards, and\nmoney you owe or are owed.',
            action: KoinPrimaryButton(
              label: 'Add credit / IOU',
              icon: KoinIcons.plus,
              onPressed: () => Navigator.push(
                context,
                SlideUpRoute(page: const AddEditDebtScreen()),
              ),
            ),
          );
        }

        return ReorderableListView.builder(
          padding: EdgeInsets.fromLTRB(
            KoinSpacing.screenInset,
            12,
            KoinSpacing.screenInset,
            KoinSpacing.bottomClearance(context),
          ),
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroSummaryCard(context, ref, summary, fmt),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: KoinSectionHeader(title: 'Your balances'),
              ),
            ],
          ),
          footer: _buildAddDebtButton(context),
          itemCount: debts.length,
          onReorderItem: (oldIndex, newIndex) {
            HapticService.medium();
            ref.read(debtsProvider.notifier).reorderDebts(oldIndex, newIndex);
          },
          proxyDecorator: koinReorderProxyDecorator,
          itemBuilder: (context, index) {
            final debt = debts[index];
            return Padding(
              key: Key(debt.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: SwipeToDeleteTile(
                key: Key('dismiss_debt_${debt.id}'),
                borderRadius: BorderRadius.circular(PortfolioCardStyle.radius),
                fillRoundedCorners: true,
                backgroundColor: AppTheme.errorColor(context),
                icon: KoinIcons.trash,
                confirmTitle: 'Delete Credit/IOU?',
                confirmDescription:
                    'Are you sure you want to delete "${debt.personName}"? This action cannot be undone.',
                onDelete: () async {
                  HapticService.heavy();
                  await ref.read(debtsProvider.notifier).deleteDebt(debt.id);
                },
                child: DebtCard(
                  debt: debt,
                  currencyFormat: fmt,
                  index: index,
                  showEntranceAnimations: showEntranceAnimations,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          KoinErrorState(onRetry: () => ref.invalidate(debtsProvider)),
    );
  }

  // ── Hero Summary Card ──
  Widget _buildHeroSummaryCard(
    BuildContext context,
    WidgetRef ref,
    DebtSummary summary,
    NumberFormat currencyFormat,
  ) {
    final settings = ref.watch(settingsProvider);
    final hideAmount = settings.hideBalance;
    final netBalance = summary.netBalance;
    final totalRepaid = summary.totalRepaid;
    final cardColor = summary.isNegative
        ? AppTheme.expenseColor(context)
        : AppTheme.primaryColor(context);

    return KoinSummaryCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      topRightAction: KoinVisibilityButton(
        hidden: hideAmount,
        subject: 'net balance',
        onPressed: () =>
            ref.read(settingsProvider.notifier).setHideBalance(!hideAmount),
      ),
      shapeStyle: SummaryShapeStyle.defaultStyle,
      margin: const EdgeInsets.only(bottom: 24),
      glowColor: cardColor,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          cardColor.withValues(alpha: 0.95),
          cardColor.withValues(alpha: 0.85),
        ],
      ),
      child: KoinSummaryContent(
        label: 'Net Balance',
        currencyCode: settings.currency.code,
        amount: hideAmount
            ? const Text(
                '****',
                semanticsLabel: 'Net balance hidden',
                style: KoinTypography.summaryAmountStyle,
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedCounter(
                  value: netBalance,
                  lastValueToken: animationSessionKey != null
                      ? 'debts_hero_total_$animationSessionKey'
                      : null,
                  formatter: (v) => currencyFormat.format(v),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  style: PortfolioCardStyle.summaryAmount,
                ),
              ),
        footer: Text(
          hideAmount
              ? 'Repayment total hidden · ${summary.activeCount} active'
              : 'Paid ${currencyFormat.format(totalRepaid)} · ${summary.activeCount} active',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: KoinTypography.labelWeight,
            fontSize: KoinTypography.small,
          ),
        ),
      ),
    ).koinEntrance(context);
  }

  Widget _buildAddDebtButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: KoinAddButton(
        label: 'Add credit / IOU',
        onPressed: () {
          HapticService.medium();
          Navigator.push(
            context,
            SlideUpRoute(page: const AddEditDebtScreen()),
          );
        },
      ),
    );
  }
}

class DebtCard extends StatelessWidget {
  final Debt debt;
  final NumberFormat currencyFormat;
  final int index;
  final bool showEntranceAnimations;

  const DebtCard({
    super.key,
    required this.debt,
    required this.currencyFormat,
    this.index = 0,
    this.showEntranceAnimations = true,
  });

  @override
  Widget build(BuildContext context) {
    final isSettled = debt.isSettled;
    final settledColor = AppTheme.incomeContentColor(context);
    final color = isSettled
        ? settledColor
        : debt.type == DebtType.owedToMe
        ? AppTheme.incomeContentColor(context)
        : AppTheme.expenseContentColor(context);

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                debt.personName,
                style: TextStyle(
                  color: AppTheme.textColor(context),
                  fontSize: KoinTypography.body,
                  fontWeight: KoinTypography.titleWeight,
                ),
                maxLines: MediaQuery.textScalerOf(context).scale(15) > 20
                    ? null
                    : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSettled) ...[
              const Gap(8),
              Text(
                'Paid off',
                style: TextStyle(
                  color: settledColor,
                  fontSize: KoinTypography.small,
                  fontWeight: KoinTypography.supportingWeight,
                ),
              ),
            ],
          ],
        ),
        const Gap(4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text.rich(
            TextSpan(
              text: currencyFormat.format(
                isSettled ? debt.amount : debt.remainingAmount,
              ),
              children: [
                if (!isSettled)
                  TextSpan(
                    text: ' left',
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: KoinTypography.small,
                      fontWeight: KoinTypography.supportingWeight,
                    ),
                  ),
              ],
            ),
            style: PortfolioCardStyle.amount(
              context,
              foreground: isSettled ? null : color,
            ),
          ),
        ),
        if (!isSettled && debt.currentAmount > 0) ...[
          const Gap(4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              'of ${currencyFormat.format(debt.amount)}',
              style: PortfolioCardStyle.label(context),
            ),
          ),
        ],
        if (!isSettled && debt.dueDate != null) ...[
          const Gap(4),
          Text(
            _formatDueDate(debt.dueDate!),
            style: PortfolioCardStyle.label(context).copyWith(
              color: debt.isOverdue()
                  ? AppTheme.errorContentColor(context)
                  : null,
            ),
          ),
        ],
      ],
    );
    final leading = Container(
      width: PortfolioCardStyle.iconSize,
      height: PortfolioCardStyle.iconSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PortfolioCardStyle.iconRadius),
      ),
      child: Center(
        child: Icon(
          debt.isPurchaseAccount
              ? KoinIcons.shoppingBag
              : isSettled
              ? KoinIcons.check
              : debt.type == DebtType.owedToMe
              ? KoinIcons.arrowDown
              : KoinIcons.arrowUp,
          color: color,
          size: 24,
        ),
      ),
    );
    Widget content = PressableScale(
      enableHaptic: false,
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          SlideUpRoute(page: DebtDetailsScreen(debtId: debt.id)),
        );
      },
      child: Container(
        padding: PortfolioCardStyle.padding,
        decoration: PortfolioCardStyle.decoration(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                (!isSettled && constraints.maxWidth < 280) ||
                MediaQuery.textScalerOf(context).scale(15) > 20;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      leading,
                      if (!isSettled) _buildRepaymentAction(context),
                    ],
                  ),
                  const Gap(12),
                  details,
                ],
              );
            }
            return Row(
              children: [
                leading,
                const Gap(16),
                Expanded(child: details),
                if (!isSettled) ...[
                  const Gap(12),
                  _buildRepaymentAction(context),
                ],
              ],
            );
          },
        ),
      ),
    );

    content = content.koinEntrance(
      context,
      enabled: showEntranceAnimations,
      token: 'debt_${debt.id}',
    );

    return content;
  }

  Widget _buildRepaymentAction(BuildContext context) {
    return IconButton.filled(
      tooltip: debt.type == DebtType.owedToMe
          ? 'Record received payment'
          : 'Record repayment',
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.primaryColor(context),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        fixedSize: const Size.square(32),
        minimumSize: const Size.square(32),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => AddRepaymentSheet.show(context, debt: debt),
      icon: Icon(KoinIcons.plus, size: 18),
    );
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final diff = dueDate.difference(now).inDays;
    if (diff < 0) return '${-diff}d overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff <= 30) return '${diff}d left';
    return DateFormat.MMMd().format(dueDate);
  }
}
