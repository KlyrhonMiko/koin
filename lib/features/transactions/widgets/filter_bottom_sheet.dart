import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/transaction_filter.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/utils/icon_utils.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late TransactionFilter _filter;
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = ref.read(transactionFilterProvider);
    _minAmountController.text = _filter.minAmount?.toString() ?? '';
    _maxAmountController.text = _filter.maxAmount?.toString() ?? '';
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _apply() {
    final min = double.tryParse(_minAmountController.text);
    final max = double.tryParse(_maxAmountController.text);

    final finalFilter = _filter.copyWith(
      minAmount: min,
      maxAmount: max,
      clearMinAmount: _minAmountController.text.isEmpty,
      clearMaxAmount: _maxAmountController.text.isEmpty,
    );

    ref.read(transactionFilterProvider.notifier).updateFilter(finalFilter);
    HapticService.medium();
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _filter = const TransactionFilter();
      _minAmountController.clear();
      _maxAmountController.clear();
    });
    HapticService.light();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountProvider).value ?? [];
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor(context).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text(
                    'Reset All',
                    style: TextStyle(
                      color: AppTheme.primaryColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
              children: [
                // Transaction Type
                _buildSectionTitle('Transaction Type'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTypeChip(null, 'All'),
                    const SizedBox(width: 8),
                    _buildTypeChip(TransactionType.income, 'Income'),
                    const SizedBox(width: 8),
                    _buildTypeChip(TransactionType.expense, 'Expense'),
                    const SizedBox(width: 8),
                    _buildTypeChip(TransactionType.transfer, 'Transfer'),
                  ],
                ),

                const SizedBox(height: 32),

                // Date Range
                _buildSectionTitle('Date Range'),
                const SizedBox(height: 12),
                _buildDateRangePicker(context),

                const SizedBox(height: 32),

                // Categories
                _buildSectionTitle('Categories'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map((c) => _buildCategoryChip(c))
                      .toList(),
                ),

                const SizedBox(height: 32),

                // Accounts
                _buildSectionTitle('Accounts'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: accounts.map((a) => _buildAccountChip(a)).toList(),
                ),

                const SizedBox(height: 32),

                // Amount Range
                _buildSectionTitle('Amount Range (${currency.symbol})'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minAmountController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Min'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _maxAmountController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Max'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Apply Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: PressableScale(
              onTap: _apply,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor(
                        context,
                      ).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Apply Filters',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTypeChip(TransactionType? type, String label) {
    final isSelected = _filter.type == type;
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() {
          _filter = _filter.copyWith(type: type, clearType: type == null);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor(context)
              : AppTheme.dividerColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textColor(context),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(dynamic category) {
    final isSelected = _filter.categoryIds.contains(category.id);
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() {
          final newIds = Set<String>.from(_filter.categoryIds);
          if (isSelected) {
            newIds.remove(category.id);
          } else {
            newIds.add(category.id);
          }
          _filter = _filter.copyWith(categoryIds: newIds);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor(context)
              : AppTheme.dividerColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.2),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconUtils.getIcon(category.iconCodePoint),
              size: 14,
              color: isSelected ? Colors.white : category.color,
            ),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountChip(dynamic account) {
    final isSelected = _filter.accountIds.contains(account.id);
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() {
          final newIds = Set<String>.from(_filter.accountIds);
          if (isSelected) {
            newIds.remove(account.id);
          } else {
            newIds.add(account.id);
          }
          _filter = _filter.copyWith(accountIds: newIds);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor(context)
              : AppTheme.dividerColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.2),
                ),
        ),
        child: Text(
          account.name,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textColor(context),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangePicker(BuildContext context) {
    final label = _filter.dateRange == null
        ? 'Select Date Range'
        : '${DateFormat.yMMMd().format(_filter.dateRange!.start)} - ${DateFormat.yMMMd().format(_filter.dateRange!.end)}';

    return PressableScale(
      onTap: () async {
        HapticService.light();
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: _filter.dateRange,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppTheme.primaryColor(context),
                  primary: AppTheme.primaryColor(context),
                  surface: AppTheme.surfaceColor(context),
                ),
              ),
              child: child!,
            );
          },
        );
        if (range != null) {
          setState(() {
            _filter = _filter.copyWith(dateRange: range);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: AppTheme.primaryColor(context),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _filter.dateRange == null
                    ? AppTheme.textLightColor(context)
                    : AppTheme.textColor(context),
              ),
            ),
            const Spacer(),
            if (_filter.dateRange != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _filter = _filter.copyWith(clearDateRange: true);
                  });
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppTheme.textLightColor(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppTheme.textLightColor(context),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppTheme.dividerColor(context).withValues(alpha: 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
