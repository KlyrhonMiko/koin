import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final fmt = NumberFormat.simpleCurrency(name: currency.code);

    return debtsAsync.when(
      data: (debts) {
        if (debts.isEmpty) {
          return KoinEmptyState.sliver(
            icon: Icons.handshake_rounded,
            title: 'No credit or IOUs',
            subtitle:
                'Track BNPL, credit cards, and\nmoney you owe or are owed.',
            action: SizedBox(
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
                    Navigator.push(
                      context,
                      SlideUpRoute(page: const AddEditDebtScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text(
                    'Add Your First Account',
                    style: TextStyle(
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
            ),
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          header: _buildHeroSummaryCard(context, summary, debts.length, fmt),
          footer: _buildAddDebtButton(context),
          itemCount: debts.length,
          onReorderItem: (oldIndex, newIndex) {
            HapticService.medium();
            ref.read(debtsProvider.notifier).reorderDebts(oldIndex, newIndex);
          },
          proxyDecorator: koinReorderProxyDecorator,
          itemBuilder: (context, index) {
            final debt = debts[index];
            return SwipeToDeleteTile(
              key: Key(debt.id),
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: BorderRadius.circular(24),
              confirmTitle: 'Delete Credit/IOU?',
              confirmDescription:
                  'Are you sure you want to delete "${debt.personName}"? This action cannot be undone.',
              onDelete: () {
                ref.read(debtsProvider.notifier).deleteDebt(debt.id);
              },
              child: DebtCard(
                debt: debt,
                currencyFormat: fmt,
                index: index,
                showEntranceAnimations: showEntranceAnimations,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: \$e')),
    );
  }

  // ── Hero Summary Card ──
  Widget _buildHeroSummaryCard(
    BuildContext context,
    DebtSummary summary,
    int activeCount,
    NumberFormat currencyFormat,
  ) {
    final netBalance = summary.netBalance;
    final totalRepaid = summary.totalRepaid;
    final cardColor = summary.isNegative
        ? AppTheme.expenseColor(context)
        : AppTheme.primaryColor(context);

    return KoinSummaryCard(
          shapeStyle: SummaryShapeStyle.debts,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Net Balance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${summary.activeCount} ACTIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              AnimatedCounter(
                value: netBalance,
                lastValueToken: animationSessionKey != null
                    ? 'debts_hero_total_$animationSessionKey'
                    : null,
                formatter: (v) => currencyFormat.format(v),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const Gap(24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Paid ${currencyFormat.format(totalRepaid)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.history_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.95, 0.95),
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildAddDebtButton(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticService.medium();
        Navigator.push(context, SlideUpRoute(page: const AddEditDebtScreen()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, top: 8),
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
            const Gap(10),
            Text(
              'Add Credit / IOU',
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
    final remaining = debt.remainingAmount;
    final color = debt.type == DebtType.owedToMe
        ? AppTheme.incomeColor(context)
        : AppTheme.expenseColor(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: () {
          HapticService.light();
          Navigator.push(
            context,
            SlideUpRoute(page: DebtDetailsScreen(debtId: debt.id)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppTheme.dividerColor(context).withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Leading Icon/Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    debt.type == DebtType.owedToMe
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
              ),
              const Gap(14),
              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.personName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textLightColor(context),
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Text(
                      currencyFormat.format(debt.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                        letterSpacing: -0.5,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isSettled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'SETTLED',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Text(
                          '${currencyFormat.format(remaining)} left',
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(8),
                        GestureDetector(
                          onTap: () {
                            HapticService.medium();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => AddRepaymentSheet(
                                debt: debt,
                                isIncrease: false,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (debt.dueDate != null) ...[
                      const Gap(4),
                      Text(
                        _formatDueDate(debt.dueDate!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: debt.isOverdue()
                              ? Colors.redAccent
                              : AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (showEntranceAnimations) {
      final delay = Duration(milliseconds: 40 * index);
      content = content
          .animate()
          .slideY(
            begin: 0.07,
            delay: delay,
            duration: 240.ms,
            curve: const Cubic(0.23, 1, 0.32, 1),
          )
          .fadeIn(delay: delay, duration: 200.ms);
    }

    return content;
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
