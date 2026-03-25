import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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
        return const Color(0xFFFF6B6B);
      case TransactionType.income:
        return const Color(0xFF00D09E);
      case TransactionType.transfer:
        return AppTheme.primaryColor(context);
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
      ('Expense', TransactionType.expense, const Color(0xFFFF6B6B), Icons.arrow_upward_rounded),
      ('Income', TransactionType.income, const Color(0xFF00D09E), Icons.arrow_downward_rounded),
      ('Transfer', TransactionType.transfer, AppTheme.primaryColor(context), Icons.swap_horiz_rounded),
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
          final tabWidth = (constraints.maxWidth - 8) / 3; // account for padding
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
  Widget _buildFormCard(BuildContext context, List categories) {
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
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: Text(
                                    'Select category',
                                    style: TextStyle(
                                      color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w400,
                                      fontSize: 15,
                                    ),
                                  ),
                                  dropdownColor: AppTheme.surfaceLightColor(context),
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor(context), fontSize: 15),
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textLightColor(context)),
                                  borderRadius: BorderRadius.circular(16),
                                  value: _selectedCategoryId,
                                  items: categories.map<DropdownMenuItem<String>>((cat) {
                                    return DropdownMenuItem(
                                      value: cat.id,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: cat.color.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'), color: cat.color, size: 16),
                                          ),
                                          const Gap(10),
                                          Text(cat.name),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedCategoryId = val;
                                    });
                                  },
                                ),
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
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text(
                              'Select account',
                              style: TextStyle(
                                color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                              ),
                            ),
                            dropdownColor: AppTheme.surfaceLightColor(context),
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor(context), fontSize: 15),
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textLightColor(context)),
                            borderRadius: BorderRadius.circular(16),
                            value: _selectedAccountId,
                            items: accounts.map((acc) {
                              return DropdownMenuItem(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: acc.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(IconData(acc.iconCodePoint, fontFamily: 'MaterialIcons'), color: acc.color, size: 16),
                                    ),
                                    const Gap(10),
                                    Text(acc.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedAccountId = val;
                              });
                            },
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
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        hint: Text(
                                          'Select destination',
                                          style: TextStyle(
                                            color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
                                            fontWeight: FontWeight.w400,
                                            fontSize: 15,
                                          ),
                                        ),
                                        dropdownColor: AppTheme.surfaceLightColor(context),
                                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor(context), fontSize: 15),
                                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textLightColor(context)),
                                        borderRadius: BorderRadius.circular(16),
                                        value: _selectedToAccountId,
                                        items: accounts.map((acc) {
                                          return DropdownMenuItem(
                                            value: acc.id,
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: acc.color.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(IconData(acc.iconCodePoint, fontFamily: 'MaterialIcons'), color: acc.color, size: 16),
                                                ),
                                                const Gap(10),
                                                Text(acc.name),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedToAccountId = val;
                                          });
                                        },
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
}
