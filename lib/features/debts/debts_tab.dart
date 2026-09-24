import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/debt.dart';
import 'package:koin/core/providers/debt_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/core/widgets/animated_counter.dart';
import 'package:koin/features/debts/add_edit_debt_screen.dart';
import 'package:koin/features/debts/debt_details_screen.dart';

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
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final fmt = NumberFormat.simpleCurrency(name: currency.code);

    return debtsAsync.when(
      data: (debts) {
        if (debts.isEmpty) {
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
                                Icons.handshake_rounded,
                                size: 56,
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.6),
                              ),
                            )
                            .animate()
                            .scale(
                              begin: const Offset(0.88, 0.88),
                              delay: 60.ms,
                              curve: Curves.easeOutBack,
                              duration: 280.ms,
                            )
                            .fadeIn(duration: 220.ms),
                        const SizedBox(height: 24),
                        Text(
                              'No debts or loans',
                              style: TextStyle(
                                color: AppTheme.textColor(context),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            )
                            .animate()
                            .slideY(
                              begin: 0.08,
                              delay: 100.ms,
                              duration: 240.ms,
                              curve: const Cubic(0.23, 1, 0.32, 1),
                            )
                            .fadeIn(duration: 200.ms, delay: 100.ms),
                        const SizedBox(height: 8),
                        Text(
                              'Keep track of money you owe\nor money owed to you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textLightColor(context),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            )
                            .animate()
                            .slideY(
                              begin: 0.08,
                              delay: 140.ms,
                              duration: 240.ms,
                              curve: const Cubic(0.23, 1, 0.32, 1),
                            )
                            .fadeIn(duration: 200.ms, delay: 140.ms),
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
                                    Navigator.push(
                                      context,
                                      SlideUpRoute(
                                        page: const AddEditDebtScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Add Your First Debt',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .slideY(
                              begin: 0.08,
                              delay: 180.ms,
                              duration: 240.ms,
                              curve: const Cubic(0.23, 1, 0.32, 1),
                            )
                            .fadeIn(duration: 200.ms, delay: 180.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }



        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          header: _buildHeroSummaryCard(context, debts, fmt),
          footer: _buildAddDebtButton(context),
          itemCount: debts.length,
          onReorderItem: (oldIndex, newIndex) {
            HapticService.medium();
            ref.read(debtsProvider.notifier).reorderDebts(oldIndex, newIndex);
          },
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final elevation = Curves.easeOut.transform(animation.value) * 16;
                final scale = 1.0 + (Curves.easeOut.transform(animation.value) * 0.03);
                return Transform.scale(
                  scale: scale,
                  child: Material(
                    elevation: elevation,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    shadowColor: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final debt = debts[index];
            return Dismissible(
              key: Key(debt.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) =>
                  _showDeleteConfirmation(context, ref, debt),
              onDismissed: (direction) {
                ref.read(debtsProvider.notifier).deleteDebt(debt.id);
              },
              background: _buildDismissBackground(context),
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
    List<Debt> debts,
    NumberFormat currencyFormat,
  ) {
    double netBalance = 0.0;
    double totalRepaid = 0.0;
    
    for (final debt in debts) {
      final remaining = debt.amount - debt.currentAmount;
      totalRepaid += debt.currentAmount;
      
      if (debt.type == DebtType.owedToMe) {
        netBalance += remaining;
      } else {
        netBalance -= remaining;
      }
    }

    final isNegative = netBalance < 0;
    final cardColor = isNegative 
        ? AppTheme.expenseColor(context) 
        : AppTheme.primaryColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(28),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor.withValues(alpha: 0.95),
            cardColor.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circles overlay for depth
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          
          Column(
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
                      '${debts.length} ACTIVE',
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
        ],
      ),
    )
    .animate()
    .fade(duration: 260.ms)
    .slideY(
      begin: 0.06,
      duration: 280.ms,
      curve: const Cubic(0.23, 1, 0.32, 1),
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
              'Add New Debt',
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
    Debt debt,
  ) async {
    return await ConfirmationSheet.show(
      context: context,
      title: 'Delete Debt?',
      description:
          'Are you sure you want to delete this debt with "${debt.personName}"? This action cannot be undone.',
      confirmLabel: 'Delete Debt',
      confirmColor: AppTheme.expenseColor(context),
      icon: Icons.delete_outline_rounded,
      isDanger: true,
    );
  }

  Widget _buildDismissBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.expenseColor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: Colors.white,
        size: 28,
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
    final progress = (debt.currentAmount / debt.amount).clamp(0.0, 1.0);
    final isSettled = progress >= 1.0;
    final remaining = (debt.amount - debt.currentAmount).clamp(
      0.0,
      debt.amount,
    );
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
                          color: _isDueOverdue(debt.dueDate!)
                              ? Colors.redAccent
                              : AppTheme.textLightColor(context).withValues(alpha: 0.6),
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
          .fadeIn(
            delay: delay,
            duration: 200.ms,
          );
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

  bool _isDueOverdue(DateTime dueDate) {
    return dueDate.isBefore(DateTime.now());
  }
}
