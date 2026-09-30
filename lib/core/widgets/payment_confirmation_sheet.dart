import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/widgets/account_picker_sheet.dart';
import 'package:koin/core/widgets/category_picker_sheet.dart';
import 'package:koin/core/widgets/selection_tile.dart';
import 'package:koin/core/widgets/numpad.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class PaymentConfirmationResult {
  final double amount;
  final String categoryId;
  final String accountId;

  const PaymentConfirmationResult({
    required this.amount,
    required this.categoryId,
    required this.accountId,
  });
}

class PaymentConfirmationSheet extends ConsumerStatefulWidget {
  final PlannedPayment payment;

  const PaymentConfirmationSheet({super.key, required this.payment});

  static Future<PaymentConfirmationResult?> show({
    required BuildContext context,
    required PlannedPayment payment,
  }) {
    HapticService.medium();
    return showModalBottomSheet<PaymentConfirmationResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PaymentConfirmationSheet(payment: payment),
    );
  }

  @override
  ConsumerState<PaymentConfirmationSheet> createState() =>
      _PaymentConfirmationSheetState();
}

class _PaymentConfirmationSheetState
    extends ConsumerState<PaymentConfirmationSheet> {
  late TextEditingController _amountController;
  late String _selectedCategoryId;
  late String _selectedAccountId;
  String _currentExpression = '';

  @override
  void initState() {
    super.initState();
    final amt = widget.payment.amount;
    if (amt == amt.truncateToDouble()) {
      _amountController = TextEditingController(text: amt.toInt().toString());
    } else {
      _amountController = TextEditingController(text: amt.toString());
    }
    _currentExpression = _amountController.text;
    _selectedCategoryId = widget.payment.categoryId;
    _selectedAccountId = widget.payment.accountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Color _getTypeColor(BuildContext context) {
    return widget.payment.type == TransactionType.expense
        ? AppTheme.expenseColor(context)
        : AppTheme.incomeColor(context);
  }

  TransactionCategory? _categoryById(
    List<TransactionCategory> list,
    String? id,
  ) {
    if (id == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  Account? _accountById(List<Account> list, String? id) {
    if (id == null) return null;
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountProvider).value ?? [];
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final typeColor = _getTypeColor(context);
    final hasAmount =
        _currentExpression.isNotEmpty && _currentExpression != '0';

    final selectedCategory = _categoryById(categories, _selectedCategoryId);
    final selectedAccount = _accountById(accounts, _selectedAccountId);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          0,
          16,
          0,
          0,
        ),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Minimal Handle ──
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(16),

            // ── Title bar ──
            Text(
              widget.payment.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.5,
              ),
            ),
            const Gap(24),

            // ── Hero Amount ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    currency.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: typeColor.withValues(alpha: 0.5),
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
                        '${currency.symbol} ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: typeColor.withValues(alpha: 0.4),
                        ),
                      ),
                      Text(
                        _currentExpression.isEmpty ? '0' : _currentExpression,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: hasAmount
                              ? typeColor
                              : typeColor.withValues(alpha: 0.3),
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
                        '= ${currency.symbol}${_amountController.text}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  const Gap(12),
                  Container(
                    width: 48,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: typeColor.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.1, curve: Curves.easeOutCubic),

            const Gap(28),

            // ── Category & Account card ──
            Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.dividerColor(
                          context,
                        ).withValues(alpha: 0.7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Category row
                        SelectionTile(
                          asCard: false,
                          fallbackIcon: Icons.category_rounded,
                          label: 'Category',
                          selectedName: selectedCategory?.name,
                          selectedColor: selectedCategory?.color,
                          selectedIconCodePoint:
                              selectedCategory?.iconCodePoint,
                          placeholder: 'Select category',
                          onTap: () => _openCategoryPicker(context),
                        ),
                        // Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(
                            height: 1,
                            color: AppTheme.dividerColor(
                              context,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        // Account row
                        SelectionTile(
                          asCard: false,
                          fallbackIcon: Icons.account_balance_wallet_rounded,
                          label: 'Account',
                          selectedName: selectedAccount?.name,
                          selectedColor: selectedAccount?.color,
                          selectedIconCodePoint: selectedAccount?.iconCodePoint,
                          selectedLogoAsset: selectedAccount?.logoAsset,
                          placeholder: 'Select account',
                          onTap: () => _openAccountPicker(context),
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 100.ms, duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic),

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
            ).animate()
             .fadeIn(delay: 200.ms, duration: 300.ms)
             .slideY(begin: 0.15, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }

  void _submit() {
    HapticService.medium();
    final amount =
        double.tryParse(_amountController.text) ??
        widget.payment.amount;
    Navigator.pop(
      context,
      PaymentConfirmationResult(
        amount: amount,
        categoryId: _selectedCategoryId,
        accountId: _selectedAccountId,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Pickers
  // ═══════════════════════════════════════════════════════
  Future<void> _openCategoryPicker(BuildContext context) async {
    final id = await showCategoryPickerSheet(
      context: context,
      ref: ref,
      selectedCategoryId: _selectedCategoryId,
      type: widget.payment.type,
      indicatorColor: _getTypeColor(context),
    );
    if (id != null && mounted) {
      setState(() => _selectedCategoryId = id);
    }
  }

  Future<void> _openAccountPicker(BuildContext context) async {
    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _selectedAccountId,
      subtitle: 'Choose the account for this payment',
    );
    if (id != null && mounted) {
      setState(() => _selectedAccountId = id);
    }
  }
}
