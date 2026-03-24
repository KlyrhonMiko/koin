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

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  String _currentExpression = '';

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _saveTransaction() {
    final isTransfer = _selectedType == TransactionType.transfer;

    if (_titleController.text.isEmpty ||
        _amountController.text.isEmpty ||
        (!isTransfer && _selectedCategoryId == null) ||
        _selectedAccountId == null ||
        (isTransfer && _selectedToAccountId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all fields'),
      ));
      return;
    }

    if (isTransfer && _selectedAccountId == _selectedToAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Source and destination accounts must be different'),
      ));
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid amount'),
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
              onPrimary: Colors.black,
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

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(title: const Text('New Transaction')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Type Selector
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.dividerColor(context)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildTypeButton(context, 'Expense', TransactionType.expense, const Color(0xFFFF6B6B)),
                        _buildTypeButton(context, 'Income', TransactionType.income, const Color(0xFF00D09E)),
                        _buildTypeButton(context, 'Transfer', TransactionType.transfer, AppTheme.primaryColor(context)),
                      ],
                    ),
                  ),
                  const Gap(28),
                  // Amount Display
                  Column(
                    children: [
                      if (_currentExpression.isNotEmpty && _currentExpression.contains(RegExp(r'[+\-*/]')))
                        Text(
                          _currentExpression,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      AbsorbPointer(
                        child: TextField(
                          controller: _amountController,
                          readOnly: true,
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: _getTypeColor(context),
                            letterSpacing: -1.5,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                            ),
                            prefixText: '${currency.symbol} ',
                            prefixStyle: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textLightColor(context).withValues(alpha: 0.4),
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(28),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g., Groceries',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const Gap(16),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        DateFormat.yMMMd().format(_selectedDate),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const Gap(16),
                  if (_selectedType != TransactionType.transfer)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      dropdownColor: AppTheme.surfaceLightColor(context),
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor(context), fontSize: 15),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      borderRadius: BorderRadius.circular(16),
                      value: _selectedCategoryId,
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat.id,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: cat.color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
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
                  if (_selectedType != TransactionType.transfer)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CategoryManagerScreen()),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined, size: 13),
                        label: const Text('Manage Categories', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 30),
                        ),
                      ),
                    ),
                  if (_selectedType != TransactionType.transfer)
                    const Gap(12),
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
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: _selectedType == TransactionType.transfer ? 'From Account' : 'Account',
                                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                                ),
                                dropdownColor: AppTheme.surfaceLightColor(context),
                                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor(context), fontSize: 15),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                borderRadius: BorderRadius.circular(16),
                                value: _selectedAccountId,
                                items: accounts.map((acc) {
                                  return DropdownMenuItem(
                                    value: acc.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: acc.color.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
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
                              if (_selectedType == TransactionType.transfer) ...[
                                const Gap(16),
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'To Account',
                                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                                  ),
                                  dropdownColor: AppTheme.surfaceLightColor(context),
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor(context), fontSize: 15),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                  borderRadius: BorderRadius.circular(16),
                                  value: _selectedToAccountId,
                                  items: accounts.map((acc) {
                                    return DropdownMenuItem(
                                      value: acc.id,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: acc.color.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
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
                              ],
                            ],
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (err, stack) => Text('Error: $err'),
                      );
                    },
                  ),
                  const Gap(32),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: AppTheme.primaryGradient(context),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text('Save Transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
                    ),
                  ),
                  const Gap(20),
                ],
              ),
            ),
          ),
          NumPad(
            initialValue: _currentExpression,
            onValueChanged: (expression, result) {
              setState(() {
                _currentExpression = expression;
                _amountController.text = result;
              });
            },
            onDone: () {
              FocusScope.of(context).unfocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(BuildContext context, String label, TransactionType type, Color color) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textLightColor(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
