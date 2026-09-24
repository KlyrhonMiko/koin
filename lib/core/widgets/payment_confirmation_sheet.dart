import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/widgets/select_sheet.dart';
import 'package:koin/core/widgets/account_item.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';

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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          0,
          12,
          0,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(16),

            // ── Title bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.dividerColor(
                            context,
                          ).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppTheme.textLightColor(context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.payment.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textLightColor(context),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: typeColor.withValues(alpha: 0.5),
                          letterSpacing: 1.5,
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
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: typeColor.withValues(alpha: 0.4),
                            ),
                          ),
                          IntrinsicWidth(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                hoverColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: TextField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                onChanged: (val) =>
                                    setState(() => _currentExpression = val),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: hasAmount
                                      ? typeColor
                                      : typeColor.withValues(alpha: 0.35),
                                  letterSpacing: -2,
                                  height: 1.1,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: TextStyle(
                                    color: typeColor.withValues(alpha: 0.35),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  isDense: true,
                                  isCollapsed: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      Container(
                        width: hasAmount ? 60 : 40,
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: typeColor.withValues(alpha: 0.25),
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
                        _buildSelectionRow(
                          context,
                          fallbackIcon: Icons.category_rounded,
                          label: 'Category',
                          selectedName: selectedCategory?.name,
                          selectedColor: selectedCategory?.color,
                          selectedIconCodePoint:
                              selectedCategory?.iconCodePoint,
                          placeholder: 'Select category',
                          onTap: () => _openCategoryPicker(context, categories),
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
                        _buildSelectionRow(
                          context,
                          fallbackIcon: Icons.account_balance_wallet_rounded,
                          label: 'Account',
                          selectedName: selectedAccount?.name,
                          selectedColor: selectedAccount?.color,
                          selectedIconCodePoint: selectedAccount?.iconCodePoint,
                          selectedLogoAsset: selectedAccount?.logoAsset,
                          placeholder: 'Select account',
                          onTap: () => _openAccountPicker(context, accounts),
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 100.ms, duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic),

            const Gap(24),

            // ── Confirm button ──
            Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            typeColor,
                            typeColor.withValues(alpha: 0.85),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: typeColor.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
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
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Confirm Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 200.ms, duration: 300.ms)
                .slideY(begin: 0.15, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Selection Row — matching Add Transaction screen
  // ═══════════════════════════════════════════════════════
  Widget _buildSelectionRow(
    BuildContext context, {
    required IconData fallbackIcon,
    required String label,
    required String? selectedName,
    required Color? selectedColor,
    required int? selectedIconCodePoint,
    String? selectedLogoAsset,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasSelection =
        selectedName != null &&
        selectedColor != null &&
        selectedIconCodePoint != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Builder(builder: (context) {

                if (hasSelection && selectedLogoAsset != null && selectedLogoAsset.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      selectedLogoAsset,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  );
                }

                return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hasSelection
                      ? selectedColor.withValues(alpha: 0.12)
                      : AppTheme.surfaceLightColor(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasSelection
                      ? IconUtils.getIcon(selectedIconCodePoint)
                      : fallbackIcon,
                  size: 17,
                  color: hasSelection
                      ? selectedColor
                      : AppTheme.textLightColor(context),
                ),
              );

              }),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.65),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      hasSelection ? selectedName : placeholder,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: hasSelection
                            ? AppTheme.textColor(context)
                            : AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textLightColor(context).withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Amount Editor Dialog
  // ═══════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════
  // Pickers — matching premium sheet style
  // ═══════════════════════════════════════════════════════
  Future<void> _openCategoryPicker(
    BuildContext context,
    List<TransactionCategory> categories,
  ) async {
    final filtered = categories
        .where((c) => c.type == widget.payment.type)
        .toList();

    final id = await _showPremiumSelectionSheet<String>(
      context: context,
      title: 'Category',
      subtitle: 'Choose a category for this payment',
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final cat = filtered[index];
        return _PremiumSheetItem(
          name: cat.name,
          accentColor: cat.color,
          iconCodePoint: cat.iconCodePoint,
          selected: cat.id == _selectedCategoryId,
          onTap: () => Navigator.pop(context, cat.id),
        );
      },
    );
    if (id != null && mounted) {
      setState(() => _selectedCategoryId = id);
    }
  }

  Future<void> _openAccountPicker(
    BuildContext context,
    List<Account> accounts,
  ) async {
    final stats = ref.read(dashboardStatsProvider);
    final currency = ref.read(settingsProvider).currency;
    final id = await showSelectSheet<String>(
      context: context,
      title: 'Account',
      subtitle: 'Choose the account for this payment',
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        return Consumer(
          builder: (context, ref, _) {
            final liveAccounts = ref.watch(accountProvider).value ?? [];
            final acc = liveAccounts.firstWhere(
              (a) => a.id == accounts[index].id,
              orElse: () => accounts[index],
            );
            final balance = stats.accountBalances[acc.id] ?? 0.0;
            return AccountItem(
              account: acc,
              balance: balance,
              currencySymbol: currency.symbol,
              isSelected: acc.id == _selectedAccountId,
              onTap: () => Navigator.pop(context, acc.id),
            );
          },
        );
      },
    );
    if (id != null && mounted) {
      setState(() => _selectedAccountId = id);
    }
  }

  Future<T?> _showPremiumSelectionSheet<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    final typeColor = _getTypeColor(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(sheetContext).padding.top + 12,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(sheetContext),
                  border: Border.all(
                    color: AppTheme.dividerColor(sheetContext),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(10),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor(sheetContext),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const Gap(10),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: AppTheme.textColor(sheetContext),
                                ),
                              ),
                            ],
                          ),
                          const Gap(4),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                                color: AppTheme.textLightColor(sheetContext),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16 + bottomInset,
                        ),
                        itemCount: itemCount,
                        separatorBuilder: (context, index) => const Gap(8),
                        itemBuilder: (context, index) {
                          return itemBuilder(context, index)
                              .animate()
                              .fadeIn(delay: (index * 40).ms, duration: 250.ms)
                              .slideX(
                                begin: 0.04,
                                duration: 250.ms,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// Premium Sheet Item — identical to Add Transaction
// ═══════════════════════════════════════════════════════
class _PremiumSheetItem extends StatelessWidget {
  const _PremiumSheetItem({
    required this.name,
    required this.accentColor,
    required this.iconCodePoint,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color accentColor;
  final int iconCodePoint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.45)
                  : AppTheme.dividerColor(context).withValues(alpha: 0.65),
              width: selected ? 1.5 : 1,
            ),
            color: selected
                ? primary.withValues(alpha: 0.08)
                : AppTheme.surfaceLightColor(context).withValues(alpha: 0.45),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconUtils.getIcon(iconCodePoint),
                  color: accentColor,
                  size: 22,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primary, size: 26)
              else
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
