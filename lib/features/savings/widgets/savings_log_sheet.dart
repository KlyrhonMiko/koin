import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

/// Modal bottom sheet for logging or editing a [SavingsLog] against a [SavingsGoal].
class SavingsLogSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final SavingsLog? log;
  final Account? linkedAccount;
  final double? linkedBalance;
  final Future<void> Function(double amount) onSave;

  const SavingsLogSheet({
    super.key,
    required this.goal,
    this.log,
    this.linkedAccount,
    this.linkedBalance,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required SavingsGoal goal,
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

  @override
  void initState() {
    super.initState();
    _currentExpression = widget.log != null
        ? widget.log!.amount.toString().replaceFirst(RegExp(r'\.0$'), '')
        : '';
    _evaluatedResult = widget.log != null ? widget.log!.amount.toString() : '0';
  }

  void _submit() async {
    final amount = double.tryParse(_evaluatedResult);
    if (amount != null && amount > 0) {
      if (widget.log == null &&
          widget.linkedAccount != null &&
          widget.linkedBalance != null &&
          amount > widget.linkedBalance!) {
        HapticService.error();
        return;
      }
      await widget.onSave(amount);
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      HapticService.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final hasAmount =
        _currentExpression.isNotEmpty && _currentExpression != '0';
    final primaryColor = AppTheme.primaryColor(context);
    final parsedAmount = double.tryParse(_evaluatedResult) ?? 0;
    final isExceeded =
        widget.log == null &&
        widget.linkedAccount != null &&
        widget.linkedBalance != null &&
        parsedAmount > widget.linkedBalance!;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
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
            widget.log != null ? 'Edit Savings' : 'Add Savings',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Gap(32),

          // Hero Amount Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  settings.currency.code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primaryColor.withValues(alpha: 0.5),
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
                        color: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      _currentExpression.isEmpty ? '0' : _currentExpression,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: isExceeded
                            ? AppTheme.expenseColor(context)
                            : (hasAmount
                                  ? primaryColor
                                  : primaryColor.withValues(alpha: 0.3)),
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
                      '= ${settings.currency.symbol}$_evaluatedResult',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (widget.linkedAccount != null &&
                    widget.linkedBalance != null &&
                    widget.log == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      isExceeded
                          ? 'Insufficient balance in ${widget.linkedAccount!.name}'
                          : 'Available from ${widget.linkedAccount!.name}: ${NumberFormat.currency(symbol: settings.currency.symbol).format(widget.linkedBalance)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isExceeded
                            ? AppTheme.expenseColor(context)
                            : AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.5),
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
            initialValue: _currentExpression,
            onValueChanged: (expression, result) {
              setState(() {
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
