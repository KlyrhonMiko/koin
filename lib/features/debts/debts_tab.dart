import 'dart:math';
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
                              delay: 200.ms,
                              curve: Curves.easeOutBack,
                              duration: 600.ms,
                            )
                            .fadeIn(),
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
                            .slideY(begin: 0.2, delay: 300.ms, duration: 400.ms)
                            .fadeIn(),
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

        final owedToMe = debts
            .where((d) => d.type == DebtType.owedToMe)
            .toList();
        final iOwe = debts.where((d) => d.type == DebtType.iOwe).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            // Hero summary card
            _buildHeroSummaryCard(context, debts, fmt),
            if (owedToMe.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                icon: Icons.arrow_downward_rounded,
                label: 'OWED TO YOU',
                color: AppTheme.incomeColor(context),
                count: owedToMe.length,
              ),
              const Gap(12),
              ...owedToMe.asMap().entries.map(
                (e) => Dismissible(
                  key: Key(e.value.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) =>
                      _showDeleteConfirmation(context, ref, e.value),
                  onDismissed: (direction) {
                    ref.read(debtsProvider.notifier).deleteDebt(e.value.id);
                  },
                  background: _buildDismissBackground(context),
                  child: DebtCard(
                    debt: e.value,
                    currencyFormat: fmt,
                    index: e.key,
                  ),
                ),
              ),
              const Gap(20),
            ],
            if (iOwe.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                icon: Icons.arrow_upward_rounded,
                label: 'YOU OWE',
                color: AppTheme.expenseColor(context),
                count: iOwe.length,
              ),
              const Gap(12),
              ...iOwe.asMap().entries.map(
                (e) => Dismissible(
                  key: Key(e.value.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) =>
                      _showDeleteConfirmation(context, ref, e.value),
                  onDismissed: (direction) {
                    ref.read(debtsProvider.notifier).deleteDebt(e.value.id);
                  },
                  background: _buildDismissBackground(context),
                  child: DebtCard(
                    debt: e.value,
                    currencyFormat: fmt,
                    index: e.key,
                  ),
                ),
              ),
              const Gap(20),
            ],
            _buildAddDebtButton(context),
          ],
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
    final totalOwedToMe = debts
        .where((d) => d.type == DebtType.owedToMe)
        .fold<double>(0, (sum, d) => sum + d.amount);
    final totalIOwe = debts
        .where((d) => d.type == DebtType.iOwe)
        .fold<double>(0, (sum, d) => sum + d.amount);
    final totalRepaid = debts.fold<double>(
      0,
      (sum, d) => sum + d.currentAmount,
    );
    final totalDebt = debts.fold<double>(0, (sum, d) => sum + d.amount);
    final overallProgress = totalDebt > 0
        ? (totalRepaid / totalDebt).clamp(0.0, 1.0)
        : 0.0;

    return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient(context),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Decorative circles
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 140,
                  height: 140,
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
              // Content
              Column(
                children: [
                  // Top label row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Repayment',
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
                          '${debts.length} debt${debts.length == 1 ? '' : 's'}',
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
                  const Gap(20),
                  // Radial gauge
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: overallProgress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedProgress, child) {
                      final animatedPercent = (animatedProgress * 100)
                          .toStringAsFixed(0);
                      return SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: _RadialProgressPainter(
                            progress: animatedProgress,
                            trackColor: Colors.white.withValues(alpha: 0.15),
                            progressColor: Colors.white,
                            strokeWidth: 8,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$animatedPercent%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    letterSpacing: -1,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'repaid',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Gap(24),
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeroStat(
                          'Owed To You',
                          totalOwedToMe,
                          currencyFormat,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildHeroStat(
                          'You Owe',
                          totalIOwe,
                          currencyFormat,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildHeroStat(
                          'Repaid',
                          totalRepaid,
                          currencyFormat,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fade(duration: 500.ms)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }

  Widget _buildHeroStat(String label, double amount, NumberFormat fmt) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(4),
        FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedCounter(
              value: amount,
              lastValueToken: animationSessionKey != null
                  ? 'debts_hero_${label.toLowerCase()}_$animationSessionKey'
                  : null,
              formatter: (v) => fmt.format(v),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const Gap(10),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textLightColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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

  static const _accentColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF00D09E), // Teal
  ];

  const DebtCard({
    super.key,
    required this.debt,
    required this.currencyFormat,
    this.index = 0,
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
    final percentText = '${(progress * 100).toInt()}%';
    final accentColor = _accentColors[index % _accentColors.length];

    return Padding(
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
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  if (isSettled)
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: avatar + name + amount
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      debt.personName,
                                      style: TextStyle(
                                        color: AppTheme.textColor(context),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSettled) ...[
                                    const Gap(8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor(
                                          context,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'SETTLED',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor(context),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Gap(4),
                              Row(
                                children: [
                                  if (debt.totalInstallments > 0) ...[
                                    Text(
                                      '${debt.totalInstallments} ${debt.frequency.name} payments',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ] else
                                    Text(
                                      isSettled
                                          ? 'Fully paid'
                                          : 'No installments',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormat.format(debt.amount),
                              style: TextStyle(
                                color: AppTheme.textColor(context),
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Gap(4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isSettled
                                    ? AppTheme.primaryColor(
                                        context,
                                      ).withValues(alpha: 0.08)
                                    : color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSettled
                                    ? 'Completed'
                                    : '${currencyFormat.format(remaining)} left',
                                style: TextStyle(
                                  color: isSettled
                                      ? AppTheme.primaryColor(context)
                                      : color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Progress bar
                    if (!isSettled && debt.amount > 0) ...[
                      const Gap(16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: Duration(milliseconds: 800 + (index * 100)),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedProgress, _) {
                            return Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: animatedProgress,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          color,
                                          color.withValues(alpha: 0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    // Bottom info row
                    const Gap(14),
                    Row(
                      children: [
                        if (!isSettled) ...[
                          // Progress percentage badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              percentText,
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Gap(10),
                        ],
                        if (debt.dueDate != null) ...[
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: 0.5),
                          ),
                          const Gap(4),
                          Text(
                            _formatDueDate(debt.dueDate!),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isDueOverdue(debt.dueDate!)
                                  ? AppTheme.expenseColor(context)
                                  : AppTheme.textLightColor(
                                      context,
                                    ).withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .slideY(
          begin: 0.15,
          delay: Duration(milliseconds: 80 * index),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(
          delay: Duration(milliseconds: 80 * index),
          duration: 350.ms,
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

  bool _isDueOverdue(DateTime dueDate) {
    return dueDate.isBefore(DateTime.now());
  }
}

// ── Radial Progress Painter ──
class _RadialProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RadialProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
