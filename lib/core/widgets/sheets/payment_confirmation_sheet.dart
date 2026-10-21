import 'package:koin/core/icons.dart';
import 'package:koin/core/utils/motion_policy.dart';
import 'package:flutter/material.dart';

import 'koin_sheet_surface.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/utils/snackbar_utils.dart';

import 'account_picker_sheet.dart';
import 'category_picker_sheet.dart';
import 'savings_spending_confirmation.dart';
import '../inputs/selection_tile.dart';
import '../inputs/numpad.dart';

import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/ledger/transaction_rules.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/savings_provider.dart';

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
  static final Set<String> _pendingPaymentIds = {};
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

  /// Displays the confirmation sheet and processes the planned payment occurrence upon confirmation.
  static Future<bool> confirmAndProcess({
    required BuildContext context,
    required WidgetRef ref,
    required PlannedPayment payment,
  }) async {
    if (!_pendingPaymentIds.add(payment.id)) return false;
    try {
      return await _confirmAndProcess(
        context: context,
        ref: ref,
        payment: payment,
      );
    } finally {
      _pendingPaymentIds.remove(payment.id);
    }
  }

  static Future<bool> _confirmAndProcess({
    required BuildContext context,
    required WidgetRef ref,
    required PlannedPayment payment,
  }) async {
    final result = await show(context: context, payment: payment);
    if (result == null || !context.mounted) return false;

    final isExpense = payment.type == TransactionType.expense;
    final transactionId = const Uuid().v4();
    final savings = ref.read(savingsGoalsProvider.notifier);
    bool processed = false;
    try {
      TransactionRules.account(
        accountId: result.accountId,
        value: result.amount,
        isExpense: isExpense,
        accounts: await ref.read(accountProvider.future),
        transactions: await ref.read(transactionProvider.future),
      );
      if (!context.mounted) return false;
      if (isExpense &&
          !await confirmSavingsSpending(
            context: context,
            ref: ref,
            accountId: result.accountId,
            amount: result.amount,
            transactionId: transactionId,
          )) {
        return false;
      }
      if (!context.mounted) return false;

      await ref
          .read(plannedPaymentProvider.notifier)
          .processOccurrence(
            payment: payment,
            amount: result.amount,
            accountId: result.accountId,
            categoryId: result.categoryId,
            transactionId: transactionId,
          );

      processed = true;

      if (context.mounted) {
        KoinSnackBar.success(
          context,
          isExpense ? 'Payment processed' : 'Income processed',
          subtitle: isExpense
              ? 'Your planned payment has been completed'
              : 'Your recurring income has been completed',
        );
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        KoinSnackBar.error(
          context,
          error is FinancialValidationException
              ? error.message
              : 'Could not process schedule',
          subtitle: 'No payment was completed. Try again.',
        );
      }
      return false;
    } finally {
      if (!processed) await savings.rollbackDraftRelease(transactionId);
    }
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
      child: KoinSheetSurface(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
        color: AppTheme.backgroundColor(context),
        shadows: [
          AppTheme.boxShadow(
            context,
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
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
                fontSize: KoinTypography.screenTitle,
                fontWeight: KoinTypography.headingWeight,
                color: AppTheme.textColor(context),
                letterSpacing: KoinTypography.headingTracking,
              ),
            ),
            const Gap(24),

            // ── Hero Amount ──
            Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KoinSpacing.screenInset,
                  ),
                  child: Column(
                    children: [
                      Text(
                        currency.code,
                        style: TextStyle(
                          fontSize: KoinTypography.overline,
                          fontWeight: KoinTypography.headingWeight,
                          color: typeColor.withValues(alpha: 0.5),
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
                            '${currency.symbol} ',
                            style: TextStyle(
                              fontSize: KoinTypography.screenTitle,
                              fontWeight: KoinTypography.labelWeight,
                              color: AppTheme.contentColor(context, typeColor),
                            ),
                          ),
                          Text(
                            _currentExpression.isEmpty
                                ? '0'
                                : _currentExpression,
                            style: KoinTypography.inputAmountStyle.copyWith(
                              color: hasAmount
                                  ? AppTheme.contentColor(context, typeColor)
                                  : AppTheme.textLightColor(context),
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
                              fontSize: KoinTypography.compact,
                              fontWeight: KoinTypography.labelWeight,
                              color: AppTheme.textLightColor(context)
                                  .withValues(alpha: 0.6),
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
                .koinAnimate(
                  context,
                  autoPlay: !MediaQuery.disableAnimationsOf(context),
                  onInit: KoinMotion.onInit(context),
                )
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic),

            const Gap(KoinSpacing.sectionGap),

            // ── Category & Account card ──
            Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KoinSpacing.screenInset,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.dividerColor(context)
                            .withValues(alpha: 0.7),
                      ),
                      boxShadow: [
                        AppTheme.boxShadow(
                          context,
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
                          fallbackIcon: KoinIcons.squaresFour,
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
                            color: AppTheme.dividerColor(context)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        // Account row
                        SelectionTile(
                          asCard: false,
                          fallbackIcon: KoinIcons.wallet,
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
                .koinAnimate(
                  context,
                  autoPlay: !MediaQuery.disableAnimationsOf(context),
                  onInit: KoinMotion.onInit(context),
                )
                .fadeIn(delay: 100.ms, duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic),

            const Gap(16),

            NumPad(
                  decimalDigits: currency.decimalDigits,
                  compact: true,
                  initialValue: _currentExpression,
                  onValueChanged: (expression, result) {
                    setState(() {
                      _currentExpression = expression;
                      _amountController.text = result;
                    });
                  },
                  onDone: _submit,
                )
                .koinAnimate(
                  context,
                  autoPlay: !MediaQuery.disableAnimationsOf(context),
                  onInit: KoinMotion.onInit(context),
                )
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
        ref
            .read(settingsProvider)
            .currency
            .tryParseInput(_amountController.text) ??
        0;
    try {
      TransactionRules.account(
        accountId: _selectedAccountId,
        value: amount,
        isExpense: widget.payment.type == TransactionType.expense,
        accounts: ref.read(accountProvider).value ?? [],
        transactions: ref.read(transactionProvider).value ?? [],
      );
      if (!(ref.read(categoriesProvider).value ?? []).any(
        (category) =>
            category.id == _selectedCategoryId &&
            category.type == widget.payment.type,
      )) {
        throw const FinancialValidationException(
          'Choose an available category',
        );
      }
    } on FinancialValidationException catch (error) {
      KoinSnackBar.error(context, error.message);
      return;
    }
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
