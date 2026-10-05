import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/core.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Interactive modal sheet to log a payment or credit increase on a [Debt].
/// Encapsulates the atomic ledger transaction and updates debt state.
class AddRepaymentSheet extends ConsumerStatefulWidget {
  final Debt debt;
  final bool isIncrease;

  const AddRepaymentSheet({
    super.key,
    required this.debt,
    this.isIncrease = false,
  });

  /// Presents [AddRepaymentSheet] in a standardized modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required Debt debt,
    bool isIncrease = false,
  }) {
    HapticService.medium();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddRepaymentSheet(debt: debt, isIncrease: isIncrease),
    );
  }

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
      final prefs = ref.read(sharedPreferencesProvider);
      final lastId = prefs.getString('last_repayment_account_id');
      if (lastId != null && accounts.any((a) => a.id == lastId)) {
        _selectedAccountId = lastId;
      } else {
        _selectedAccountId = accounts.first.id;
      }
      _accountInitialized = true;
    }

    final selectedAccount = _selectedAccountId != null
        ? accounts.cast<Account?>().firstWhere(
            (a) => a?.id == _selectedAccountId,
            orElse: () => null,
          )
        : null;

    String? displayAccountName;
    if (selectedAccount != null) {
      final balance =
          ref
              .watch(dashboardStatsProvider)
              .accountBalances[selectedAccount.id] ??
          selectedAccount.initialBalance;
      final balanceStr = balance == balance.toInt()
          ? balance.toInt().toString()
          : balance.toStringAsFixed(2);
      displayAccountName =
          '${selectedAccount.name} • ${settings.currency.symbol}$balanceStr';
    }

    final hasAmount =
        _currentExpression.isNotEmpty && _currentExpression != '0';

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
          _noteFocusNode.hasFocus
              ? (MediaQuery.of(context).padding.bottom + 24)
              : 0,
        ),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            AppTheme.boxShadow(
              context,
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
            const KoinBottomSheetHandle(),
            const Gap(24),

            // ── Title ──
            Text(
              widget.isIncrease ? 'Increase Credit' : 'Log Payment',
              style: TextStyle(
                fontSize: KoinTypography.screenTitle,
                fontWeight: KoinTypography.headingWeight,
                color: AppTheme.textColor(context),
                letterSpacing: KoinTypography.headingTracking,
              ),
            ),

            const Gap(24),

            // ── Amount Input Display ──
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
                          color: color.withValues(alpha: 0.5),
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
                              color: color.withValues(alpha: 0.4),
                            ),
                          ),
                          Text(
                            _currentExpression.isEmpty
                                ? '0'
                                : _currentExpression,
                            style: TextStyle(
                              fontSize: KoinTypography.inputAmount,
                              fontWeight: FontWeight.w800,
                              color: hasAmount
                                  ? color
                                  : color.withValues(alpha: 0.3),
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
                            '= ${settings.currency.symbol}${_amountController.text}',
                            style: TextStyle(
                              fontSize: KoinTypography.compact,
                              fontWeight: KoinTypography.labelWeight,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      if (!widget.isIncrease) ...[
                        const Gap(12),
                        Text(
                          'Remaining Credit: ${NumberFormat.currency(symbol: settings.currency.symbol, customPattern: '\u00a4#,##0.##').format(widget.debt.remainingAmount)}',
                          style: TextStyle(
                            fontSize: KoinTypography.compact,
                            fontWeight: KoinTypography.supportingWeight,
                            color: AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      const Gap(16),
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
                )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.05, curve: Curves.easeOutCubic),
            const Gap(32),

            // ── Account & Note Fields ──
            Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KoinSpacing.screenInset,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.dividerColor(
                          context,
                        ).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        SelectionTile(
                          asCard: false,
                          fallbackIcon: Icons.account_balance_wallet_rounded,
                          label: isAccountRequired
                              ? 'Account'
                              : 'Account (Optional)',
                          selectedName: displayAccountName,
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
                          color: AppTheme.dividerColor(
                            context,
                          ).withValues(alpha: 0.5),
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
                                  onTapOutside: (_) => FocusManager
                                      .instance
                                      .primaryFocus
                                      ?.unfocus(),
                                  style: TextStyle(
                                    fontWeight: KoinTypography.supportingWeight,
                                    fontSize: KoinTypography.body,
                                    color: AppTheme.textColor(context),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add a note...',
                                    hintStyle: TextStyle(
                                      color: AppTheme.textLightColor(
                                        context,
                                      ).withValues(alpha: 0.4),
                                      fontWeight: FontWeight.w400,
                                      fontSize: KoinTypography.body,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  duration: 250.ms,
                  curve: Curves.easeOutCubic,
                ),

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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KoinSpacing.screenInset,
                ),
                child:
                    SizedBox(
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
                              widget.isIncrease
                                  ? 'Confirm Increase'
                                  : 'Confirm Payment',
                              style: const TextStyle(
                                fontSize: KoinTypography.itemTitle,
                                fontWeight: KoinTypography.titleWeight,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        ),
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

    if (!widget.isIncrease &&
        (amt * 100).round() > (widget.debt.remainingAmount * 100).round()) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Amount Exceeds Credit',
        subtitle: 'You cannot pay more than the remaining balance',
      );
      return;
    }

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

    if (selectedAccount != null &&
        !selectedAccount.isCredit &&
        !widget.isIncrease) {
      final currentBalance =
          ref
              .read(dashboardStatsProvider)
              .accountBalances[selectedAccount.id] ??
          selectedAccount.initialBalance;
      if ((amt * 100).round() > (currentBalance * 100).round()) {
        HapticService.error();
        KoinSnackBar.error(
          context,
          'Insufficient balance',
          subtitle: 'A debit account cannot go negative',
        );
        return;
      }
    }

    if (_selectedAccountId != null) {
      ref
          .read(sharedPreferencesProvider)
          .setString('last_repayment_account_id', _selectedAccountId!);
    }

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

    // Atomically persist repayment, mutate debt balance, and record ledger transaction
    await ref
        .read(debtsProvider.notifier)
        .processRepayment(
          debt: widget.debt,
          repayment: repayment,
          categoryId: widget.debt.categoryId,
        );

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
      subtitle: widget.isIncrease
          ? 'Which account was used?'
          : 'Choose the account for this payment',
      allowNone: widget.isIncrease,
      noneLabel: 'No Account (Balance only)',
      accountsOverride: accounts,
    );
    if (id != null && mounted) {
      setState(() => _selectedAccountId = id.isEmpty ? null : id);
    }
  }
}
