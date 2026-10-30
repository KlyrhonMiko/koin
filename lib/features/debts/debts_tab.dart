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

    Widget content = PressableScale(
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
            final compact =
                constraints.maxWidth < 240 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.2;
            return Row(
              children: [
                // Leading Icon/Avatar
                Container(
                  width: PortfolioCardStyle.iconSize,
                  height: PortfolioCardStyle.iconSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      PortfolioCardStyle.iconRadius,
                    ),
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
                ),
                const Gap(16),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.personName,
                        style: PortfolioCardStyle.label(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          currencyFormat.format(debt.amount),
                          style: PortfolioCardStyle.amount(context),
                        ),
                      ),
                      if (compact) ...[
                        const Gap(8),
                        _buildStatus(context, color),
                      ],
                    ],
                  ),
                ),
                if (!compact) ...[
                  const Gap(12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildStatus(context, color),
                    ),
                  ),
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

  Widget _buildStatus(BuildContext context, Color color) {
    final isSettled = debt.isSettled;
    final remaining = debt.remainingAmount;
    final settledColor = AppTheme.incomeContentColor(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSettled)
          Text(
            'Paid off',
            style: TextStyle(
              color: settledColor,
              fontSize: KoinTypography.small,
              fontWeight: KoinTypography.labelWeight,
            ),
          )
        else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${currencyFormat.format(remaining)} left',
                    style: TextStyle(
                      color: color,

                      fontSize: KoinTypography.small,
                      fontWeight: KoinTypography.labelWeight,
                    ),
                  ),
                ),
              ),
              const Gap(8),
              IconButton(
                tooltip: debt.type == DebtType.owedToMe
                    ? 'Record received payment'
                    : 'Record repayment',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => AddRepaymentSheet.show(context, debt: debt),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(KoinIcons.plus, size: 14, color: color),
                ),
              ),
            ],
          ),
          if (debt.dueDate != null) ...[
            const Gap(4),
            Text(
              _formatDueDate(debt.dueDate!),
              style: TextStyle(
                fontSize: KoinTypography.overline,
                fontWeight: KoinTypography.supportingWeight,
                color: debt.isOverdue()
                    ? AppTheme.errorContentColor(context)
                    : AppTheme.textLightColor(context).withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ],
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
