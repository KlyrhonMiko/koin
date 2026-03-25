import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/numpad.dart';
import 'package:koin/features/categories/category_manager_screen.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  String _currentExpression = '';

  late AnimationController _typeAnimController;

  @override
  void initState() {
    super.initState();
    _typeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _typeAnimController.dispose();
    super.dispose();
  }

  void _saveTransaction() {
    final isTransfer = _selectedType == TransactionType.transfer;

    if (_titleController.text.isEmpty ||
        _amountController.text.isEmpty ||
        (!isTransfer && _selectedCategoryId == null) ||
        _selectedAccountId == null ||
        (isTransfer && _selectedToAccountId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fill all fields'),
        backgroundColor: AppTheme.errorColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (isTransfer && _selectedAccountId == _selectedToAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Source and destination accounts must be different'),
        backgroundColor: AppTheme.errorColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please enter a valid amount'),
        backgroundColor: AppTheme.errorColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final newTransaction = AppTransaction(
      id: const Uuid().v4(),
      title: _titleController.text,
      amount: amount,
      date: _selectedDate,
      type: _selectedType,
      categoryId: isTransfer ? 'cat_others' : _selectedCategoryId!,
      accountId: _selectedAccountId!,
      toAccountId: isTransfer ? _selectedToAccountId : null,
    );

    ref.read(transactionProvider.notifier).addTransaction(newTransaction);
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryColor(context),
              onPrimary: Colors.white,
              surface: AppTheme.surfaceColor(context),
              onSurface: AppTheme.textColor(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Color _getTypeColor(BuildContext context) {
    switch (_selectedType) {
      case TransactionType.expense:
        return AppTheme.expenseColor(context);
      case TransactionType.income:
        return AppTheme.incomeColor(context);
      case TransactionType.transfer:
        return AppTheme.transferColor(context);
    }
  }

  int get _typeIndex {
    switch (_selectedType) {
      case TransactionType.expense:
        return 0;
      case TransactionType.income:
        return 1;
      case TransactionType.transfer:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final typeColor = _getTypeColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Transaction'),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.dividerColor(context)),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.textColor(context)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Type Selector with sliding pill ──
                  _buildTypeSelector(context, typeColor),
                  const Gap(20),

                  // ── Hero Amount Display ──
                  _buildAmountDisplay(context, currency, typeColor),
                  const Gap(20),

                  // ── Form Card ──
                  _buildFormCard(context, categories),
                  const Gap(16),
                ],
              ),
            ),
          ),
          NumPad(
            compact: true,
            initialValue: _currentExpression,
            onValueChanged: (expression, result) {
              setState(() {
                _currentExpression = expression;
                _amountController.text = result;
              });
            },
            onDone: () {
              _saveTransaction();
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Type Selector — glass pill slider
  // ═══════════════════════════════════════════════════════
  Widget _buildTypeSelector(BuildContext context, Color activeColor) {
    final types = [
      ('Expense', TransactionType.expense, AppTheme.expenseColor(context), Icons.arrow_upward_rounded),
      ('Income', TransactionType.income, AppTheme.incomeColor(context), Icons.arrow_downward_rounded),
      ('Transfer', TransactionType.transfer, AppTheme.transferColor(context), Icons.swap_horiz_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 3;
          return Stack(
            children: [
              // Sliding pill indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: _typeIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab labels
              Row(
                children: types.map((t) {
                  final isSelected = _selectedType == t.$2;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = t.$2),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              t.$4,
                              size: 16,
                              color: isSelected ? Colors.white : AppTheme.textLightColor(context),
                            ),
                            const Gap(4),
                            Text(
                              t.$1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textLightColor(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Hero Amount Display
  // ═══════════════════════════════════════════════════════
  Widget _buildAmountDisplay(BuildContext context, dynamic currency, Color typeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: typeColor.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Expression preview pill
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: (_currentExpression.isNotEmpty && _currentExpression.contains(RegExp(r'[+\-*/]')))
                ? Container(
                    key: ValueKey(_currentExpression),
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLightColor(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentExpression,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textLightColor(context),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
          const Gap(4),
          // Currency label
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: typeColor.withValues(alpha: 0.6),
              letterSpacing: 1.2,
            ),
            child: Text(currency.code),
          ),
          const Gap(2),
          // Main amount
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: typeColor.withValues(alpha: 0.5),
                ),
                child: Text('${currency.symbol} '),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: typeColor,
                  letterSpacing: -2,
                ),
                child: Text(
                  _amountController.text.isEmpty ? '0' : _amountController.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Form Card — all fields grouped together
  // ═══════════════════════════════════════════════════════
  Widget _buildFormCard(BuildContext context, List<TransactionCategory> categories) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title field
          _buildFormRow(
            context,
            icon: Icons.edit_rounded,
            child: TextField(
              controller: _titleController,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppTheme.textColor(context),
              ),
              decoration: InputDecoration(
                hintText: 'What was this for?',
                hintStyle: TextStyle(
                  color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          _divider(context),

          // Date field
          _buildFormRow(
            context,
            icon: Icons.calendar_today_rounded,
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMM d').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedDate.year == DateTime.now().year &&
                                _selectedDate.month == DateTime.now().month &&
                                _selectedDate.day == DateTime.now().day
                            ? 'Today'
                            : DateFormat('yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _divider(context),

          // Category (only for non-transfer)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                SizeTransition(sizeFactor: anim, child: FadeTransition(opacity: anim, child: child)),
            child: _selectedType != TransactionType.transfer
                ? Column(
                    key: const ValueKey('category_section'),
                    children: [
                      _buildFormRow(
                        context,
                        icon: Icons.category_rounded,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildPickerTrigger(
                                context: context,
                                hint: 'Select category',
                                selectedName: _categoryById(categories, _selectedCategoryId)?.name,
                                selectedColor: _categoryById(categories, _selectedCategoryId)?.color,
                                selectedIconCodePoint: _categoryById(categories, _selectedCategoryId)?.iconCodePoint,
                                onTap: () => _openCategoryPicker(context, categories),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLightColor(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                tooltip: 'Manage categories',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CategoryManagerScreen()),
                                  );
                                },
                                icon: Icon(Icons.tune_rounded, size: 20, color: AppTheme.textLightColor(context)),
                                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _divider(context),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('no_category')),
          ),

          // Account
          Consumer(
            builder: (context, ref, child) {
              final accountsAsync = ref.watch(accountProvider);

              return accountsAsync.when(
                data: (accounts) {
                  if (_selectedAccountId == null && accounts.isNotEmpty) {
                    _selectedAccountId = accounts.first.id;
                  }

                  return Column(
                    children: [
                      _buildFormRow(
                        context,
                        icon: Icons.account_balance_wallet_rounded,
                        label: _selectedType == TransactionType.transfer ? 'From' : null,
                        child: _buildPickerTrigger(
                          context: context,
                          hint: 'Select account',
                          selectedName: _accountById(accounts, _selectedAccountId)?.name,
                          selectedColor: _accountById(accounts, _selectedAccountId)?.color,
                          selectedIconCodePoint: _accountById(accounts, _selectedAccountId)?.iconCodePoint,
                          onTap: () => _openAccountPicker(
                            context,
                            accounts,
                            title: 'Account',
                            subtitle: _selectedType == TransactionType.transfer
                                ? 'Choose where the money leaves from'
                                : 'Choose the account for this transaction',
                            selectedId: _selectedAccountId,
                            onSelected: (id) => setState(() => _selectedAccountId = id),
                          ),
                        ),
                      ),
                      // To Account (transfer only)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            SizeTransition(sizeFactor: anim, child: FadeTransition(opacity: anim, child: child)),
                        child: _selectedType == TransactionType.transfer
                            ? Column(
                                key: const ValueKey('to_account'),
                                children: [
                                  _divider(context),
                                  _buildFormRow(
                                    context,
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: 'To',
                                    child: _buildPickerTrigger(
                                      context: context,
                                      hint: 'Select destination',
                                      selectedName: _accountById(accounts, _selectedToAccountId)?.name,
                                      selectedColor: _accountById(accounts, _selectedToAccountId)?.color,
                                      selectedIconCodePoint: _accountById(accounts, _selectedToAccountId)?.iconCodePoint,
                                      onTap: () => _openAccountPicker(
                                        context,
                                        accounts,
                                        title: 'Destination',
                                        subtitle: 'Choose where the money arrives',
                                        selectedId: _selectedToAccountId,
                                        excludeAccountId: _selectedAccountId,
                                        onSelected: (id) => setState(() => _selectedToAccountId = id),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(key: ValueKey('no_to_account')),
                      ),
                    ],
                  );
                },
                loading: () => Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primaryColor(context),
                    ),
                  ),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $err',
                      style: TextStyle(color: AppTheme.errorColor(context), fontSize: 13)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════

  Widget _buildFormRow(BuildContext context, {
    required IconData icon,
    required Widget child,
    String? label,
  }) {
    return Padding(
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
            child: Icon(icon, size: 18, color: AppTheme.textLightColor(context)),
          ),
          if (label != null) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          const Gap(12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppTheme.dividerColor(context).withValues(alpha: 0.5)),
    );
  }

  TransactionCategory? _categoryById(List<TransactionCategory> list, String? id) {
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

  Widget _buildPickerTrigger({
    required BuildContext context,
    required String hint,
    required String? selectedName,
    required Color? selectedColor,
    required int? selectedIconCodePoint,
    required VoidCallback onTap,
  }) {
    final hasSelection = selectedName != null && selectedColor != null && selectedIconCodePoint != null;
    final name = selectedName;
    final color = selectedColor;
    final iconCp = selectedIconCodePoint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              if (hasSelection && color != null && iconCp != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    IconData(iconCp, fontFamily: 'MaterialIcons'),
                    color: color,
                    size: 16,
                  ),
                ),
                const Gap(10),
              ],
              Expanded(
                child: Text(
                  hasSelection && name != null ? name : hint,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: hasSelection
                        ? AppTheme.textColor(context)
                        : AppTheme.textLightColor(context).withValues(alpha: 0.5),
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textLightColor(context), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCategoryPicker(BuildContext context, List<TransactionCategory> categories) async {
    final id = await _showPremiumSelectionSheet<String>(
      context: context,
      title: 'Category',
      subtitle: 'Choose a category for this transaction',
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
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
    List<Account> accounts, {
    required String title,
    required String subtitle,
    required String? selectedId,
    required void Function(String?) onSelected,
    String? excludeAccountId,
  }) async {
    final filtered = excludeAccountId == null
        ? accounts
        : accounts.where((a) => a.id != excludeAccountId).toList();
    final id = await _showPremiumSelectionSheet<String>(
      context: context,
      title: title,
      subtitle: subtitle,
      itemCount: filtered.length,
      emptyMessage: filtered.isEmpty ? 'No other accounts available' : null,
      itemBuilder: (context, index) {
        final acc = filtered[index];
        return _PremiumSheetItem(
          name: acc.name,
          accentColor: acc.color,
          iconCodePoint: acc.iconCodePoint,
          selected: acc.id == selectedId,
          onTap: () => Navigator.pop(context, acc.id),
        );
      },
    );
    if (id != null && mounted) {
      onSelected(id);
    }
  }

  Future<T?> _showPremiumSelectionSheet<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    String? emptyMessage,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(sheetContext).padding.top + 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(sheetContext),
                  border: Border.all(color: AppTheme.dividerColor(sheetContext)),
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
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: AppTheme.textColor(sheetContext),
                          ),
                        ),
                        const Gap(4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: AppTheme.textLightColor(sheetContext),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (emptyMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                      child: Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textLightColor(sheetContext),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
                        itemCount: itemCount,
                        separatorBuilder: (context, index) => const Gap(8),
                        itemBuilder: itemBuilder,
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primary.withValues(alpha: 0.45) : AppTheme.dividerColor(context).withValues(alpha: 0.65),
              width: selected ? 1.5 : 1,
            ),
            color: selected ? primary.withValues(alpha: 0.08) : AppTheme.surfaceLightColor(context).withValues(alpha: 0.45),
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
                  IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
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
                          color: AppTheme.textLightColor(context).withValues(alpha: 0.25),
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
