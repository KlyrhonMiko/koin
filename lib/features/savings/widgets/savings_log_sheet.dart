import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

/// Modal bottom sheet for logging or editing a [SavingsLog] against a [SavingsGoal].
class SavingsLogSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final bool release;
  final SavingsLog? log;
  final Account? linkedAccount;
  final double? linkedBalance;
  final Future<void> Function(double amount) onSave;

  const SavingsLogSheet({
    super.key,
    required this.goal,
    this.release = false,
    this.log,
    this.linkedAccount,
    this.linkedBalance,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required SavingsGoal goal,
    bool release = false,
    SavingsLog? log,
    Account? linkedAccount,
    double? linkedBalance,
    required Future<void> Function(double amount) onSave,
  }) {
    HapticService.light();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SavingsLogSheet(
        goal: goal,
        release: release,
        log: log,
        linkedAccount: linkedAccount,
        linkedBalance: linkedBalance,
        onSave: onSave,
      ),
    );
  }

  @override
  ConsumerState<SavingsLogSheet> createState() => _SavingsLogSheetState();
}

class _SavingsLogSheetState extends ConsumerState<SavingsLogSheet> {
  late String _currentExpression;
  late String _evaluatedResult;
  bool _saving = false;
  String? _saveError;

  bool get _isRelease => widget.release || (widget.log?.amount ?? 0) < 0;

  double? _availableBalance() {
    if (_isRelease) {
      final current =
          ref
              .read(savingsGoalsProvider)
              .value
              ?.where((g) => g.id == widget.goal.id)
              .firstOrNull ??
          widget.goal;
      return current.currentAmount - (widget.log?.amount ?? 0);
    }
    final accountId = widget.goal.linkedAccountId;
    if (accountId == null) return null;
    final available = ref.read(savingsAvailableBalanceProvider(accountId));
    return available == null ? null : available + (widget.log?.amount ?? 0);
  }

  @override
  void initState() {
    super.initState();
    _currentExpression = widget.log != null
        ? widget.log!.amount.abs().toString().replaceFirst(RegExp(r'\.0$'), '')
        : '';
    _evaluatedResult = widget.log != null
        ? widget.log!.amount.abs().toString()
        : '0';
  }

  void _submit() async {
    if (_saving) return;
    final amount = double.tryParse(_evaluatedResult);
    final available = _availableBalance();
    String? error;
    if (amount == null || !amount.isFinite || amount <= 0) {
      error = 'Enter a valid savings amount';
    } else if (_isRelease &&
        (amount * 100).round() > ((available ?? 0) * 100).round()) {
      error = 'You cannot release more than the saved amount';
    } else if (!_isRelease &&
        widget.goal.linkedAccountId != null &&
        (widget.log == null || amount > widget.log!.amount) &&
        (available == null ||
            (amount * 100).round() > (available * 100).round())) {
      error = available == null
          ? 'Account balance is unavailable. Try again'
          : 'Insufficient available balance in the linked account';
    }
    if (error != null) {
      setState(() => _saveError = error);
      HapticService.error();
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (_isRelease) {
        final money = NumberFormat.currency(
          symbol: ref.read(settingsProvider).currency.symbol,
        );
        final confirmed = await ConfirmationSheet.show(
          context: context,
          title: 'Release savings?',
          description:
              '${money.format(amount)} will be available to spend. ${money.format((available ?? 0) - amount!)} remains in ${widget.goal.name}.',
          confirmLabel: 'Release savings',
          confirmColor: AppTheme.primaryColor(context),
          icon: Icons.south_west_rounded,
        );
        if (confirmed != true || !mounted) return;
      }
      await widget.onSave(_isRelease ? -amount! : amount!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _saveError = e is SavingsBalanceException
              ? e.message
              : 'Could not save savings. Try again',
        );
        HapticService.error();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final hasAmount =
        _currentExpression.isNotEmpty && _currentExpression != '0';
    final primaryColor = AppTheme.primaryColor(context);
    final parsedAmount = double.tryParse(_evaluatedResult) ?? 0;
    final accountId = widget.goal.linkedAccountId;
    final available = accountId == null
        ? null
        : ref.watch(savingsAvailableBalanceProvider(accountId));
    final editableBalance = _isRelease
        ? _availableBalance()
        : available == null
        ? null
        : available + (widget.log?.amount ?? 0);
    final isExceeded =
        (_isRelease || accountId != null) &&
        editableBalance != null &&
        parsedAmount > (widget.log?.amount ?? 0) &&
        (parsedAmount * 100).round() > (editableBalance * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          AppTheme.boxShadow(
            context,
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(12),
          const KoinBottomSheetHandle(),
          const Gap(24),
          Text(
            _isRelease
                ? (widget.log != null ? 'Edit Release' : 'Release Savings')
                : (widget.log != null ? 'Edit Savings' : 'Add Savings'),
            style: const TextStyle(
              fontSize: KoinTypography.sectionTitle,
              fontWeight: KoinTypography.headingWeight,
              letterSpacing: KoinTypography.headingTracking,
            ),
          ),
          const Gap(32),

          // Hero Amount Display
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KoinSpacing.screenInset,
            ),
            child: Column(
              children: [
                Text(
                  settings.currency.code,
                  style: TextStyle(
                    fontSize: KoinTypography.overline,
                    fontWeight: KoinTypography.headingWeight,
                    color: primaryColor.withValues(alpha: 0.5),
                    letterSpacing: KoinTypography.overlineTracking,
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
                        fontSize: KoinTypography.screenTitle,
                        fontWeight: KoinTypography.labelWeight,
                        color: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      _currentExpression.isEmpty ? '0' : _currentExpression,
                      style: TextStyle(
                        fontSize: KoinTypography.inputAmount,
                        fontWeight: FontWeight.w800,
                        color: isExceeded
                            ? AppTheme.expenseColor(context)
                            : (hasAmount
                                  ? primaryColor
                                  : primaryColor.withValues(alpha: 0.3)),
                        letterSpacing: -2,
                        height: KoinTypography.amountHeight,
                      ),
                    ),
                  ],
                ),
                if (_currentExpression.contains(RegExp(r'[+\-*/]')))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '= ${settings.currency.symbol}$_evaluatedResult',
                      style: TextStyle(
                        fontSize: KoinTypography.compact,
                        fontWeight: KoinTypography.labelWeight,
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (_isRelease || accountId != null || _saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _saveError ??
                            (_isRelease
                                ? 'Available to release: ${NumberFormat.currency(symbol: settings.currency.symbol).format(editableBalance ?? 0)}'
                                : isExceeded
                                ? 'Insufficient available balance in ${widget.linkedAccount?.name ?? 'the linked account'}'
                                : editableBalance == null
                                ? 'Account balance is unavailable'
                                : 'Available for savings: ${NumberFormat.currency(symbol: settings.currency.symbol).format(editableBalance.clamp(0, double.infinity))}'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: KoinTypography.small,
                          fontWeight: KoinTypography.labelWeight,
                          color: isExceeded || _saveError != null
                              ? AppTheme.expenseColor(context)
                              : AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                const Gap(12),
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),

          const Gap(32),

          NumPad(
            compact: true,
            doneLabel: _isRelease ? 'Release' : 'Save',
            initialValue: _currentExpression,
            onValueChanged: (expression, result) {
              setState(() {
                _saveError = null;
                _currentExpression = expression;
                _evaluatedResult = result;
              });
            },
            onDone: _submit,
          ),
        ],
      ),
    );
  }
}
