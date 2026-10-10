import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme.dart';

/// Confirm and release only the savings needed to cover this debit.
Future<bool> confirmSavingsSpending({
  required BuildContext context,
  required WidgetRef ref,
  required String accountId,
  required double amount,
  String? transactionId,
  double previousDebit = 0,
  double? balance,
  Color? barrierColor,
  ValueChanged<bool>? onSheetVisibilityChanged,
  ValueChanged<double>? onSheetHeightChanged,
}) async {
  final accounts = ref.read(accountProvider).value ?? [];
  if (accounts.where((a) => a.id == accountId).firstOrNull?.isCredit == true) {
    return true;
  }
  final goals = await ref.read(savingsGoalsProvider.future);
  final linked =
      goals
          .where((g) => g.linkedAccountId == accountId && g.currentAmount > 0)
          .toList()
        ..sort((a, b) {
          final date = a.startDate.compareTo(b.startDate);
          return date == 0 ? a.id.compareTo(b.id) : date;
        });
  if (linked.isEmpty) return true;
  final actual =
      balance ?? ref.read(dashboardStatsProvider).accountBalances[accountId];
  if (actual == null || !context.mounted) return false;
  final reservedCents = linked.fold<int>(
    0,
    (sum, g) => sum + (g.currentAmount * 100).round(),
  );
  final availableCents =
      ((actual + previousDebit) * 100).round() - reservedCents;
  var neededCents = (amount * 100).round() - availableCents;
  if (neededCents <= 0) return true;
  neededCents = math.min(neededCents, reservedCents);
  final releases = <({SavingsGoal goal, double amount})>[];
  for (final goal in linked) {
    final cents = math.min(neededCents, (goal.currentAmount * 100).round());
    if (cents > 0) releases.add((goal: goal, amount: cents / 100));
    neededCents -= cents;
    if (neededCents == 0) break;
  }
  if (releases.isEmpty) return true;
  final notifier = ref.read(savingsGoalsProvider.notifier);
  final money = NumberFormat.currency(
    symbol: ref.read(settingsProvider).currency.symbol,
  );
  ModalRoute<dynamic>? sheetRoute;
  onSheetVisibilityChanged?.call(true);
  try {
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: AppTheme.surfaceColor(context),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          clipBehavior: Clip.antiAlias,
          showDragHandle: true,
          enableDrag: true,
          barrierColor: barrierColor,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) {
            sheetRoute = ModalRoute.of(context);
            return _SavingsReleaseSheet(
              releases: releases,
              available: math.max(0, availableCents) / 100,
              money: money,
              onHeightChanged: onSheetHeightChanged,
              onRelease: () => notifier.releaseForSpending([
                for (final release in releases)
                  SavingsLog(
                    id: const Uuid().v4(),
                    goalId: release.goal.id,
                    amount: -release.amount,
                    date: DateTime.now(),
                    note: 'Automatically released for spending',
                    transactionId: transactionId,
                  ),
              ], spendingAmount: amount),
            );
          },
        ) ??
        false;
  } finally {
    // Restore the quick-entry window after the sheet's exit animation.
    await sheetRoute?.completed;
    onSheetVisibilityChanged?.call(false);
  }
}

class _SavingsReleaseSheet extends StatefulWidget {
  const _SavingsReleaseSheet({
    required this.releases,
    required this.available,
    required this.money,
    required this.onRelease,
    this.onHeightChanged,
  });
  final List<({SavingsGoal goal, double amount})> releases;
  final double available;
  final NumberFormat money;
  final Future<void> Function() onRelease;
  final ValueChanged<double>? onHeightChanged;
  @override
  State<_SavingsReleaseSheet> createState() => _SavingsReleaseSheetState();
}

class _SavingsReleaseSheetState extends State<_SavingsReleaseSheet> {
  bool _saving = false;
  String? _error;
  final _contentKey = GlobalKey();
  double? _reportedHeight;

  void _reportHeight() {
    if (!mounted) return;
    final box = _contentKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    // Include the route's 48px drag handle and the bottom safe area.
    final height = box.size.height + 48 + MediaQuery.paddingOf(context).bottom;
    if (height == _reportedHeight) return;
    _reportedHeight = height;
    widget.onHeightChanged?.call(height);
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onRelease();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not release savings. Cancel and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
    final color = AppTheme.primaryColor(context);
    final total = widget.releases.fold<double>(0, (sum, r) => sum + r.amount);
    final bodyStyle = TextStyle(
      fontSize: KoinTypography.body,
      height: 1.5,
      color: AppTheme.textLightColor(context),
    );
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            key: _contentKey,
            padding: const EdgeInsets.fromLTRB(
              KoinSpacing.screenInset,
              12,
              KoinSpacing.screenInset,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.savings_outlined, size: 32, color: color),
                const SizedBox(height: 16),
                Text(
                  'Use savings for this?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: KoinTypography.screenTitle,
                    fontWeight: KoinTypography.headingWeight,
                    color: AppTheme.textColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have ${widget.money.format(widget.available)} available. Continuing will automatically release ${widget.money.format(total)} from your savings to cover the rest.',
                  textAlign: TextAlign.center,
                  style: bodyStyle,
                ),
                const SizedBox(height: 24),
                for (final release in widget.releases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          release.goal.name,
                          style: TextStyle(
                            fontSize: KoinTypography.itemTitle,
                            fontWeight: KoinTypography.titleWeight,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.money.format(release.amount)} will be released · ${widget.money.format(release.goal.currentAmount - release.amount)} remains saved',
                          style: bodyStyle,
                        ),
                      ],
                    ),
                  ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: AppTheme.expenseColor(context)),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _saving ? 'Releasing savings…' : 'Release & continue',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
