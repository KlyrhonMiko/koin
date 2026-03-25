import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveBudgets() {
    final categories = ref.read(categoryProvider);
    final notifier = ref.read(categoryProvider.notifier);

    for (var category in categories) {
      final controller = _controllers[category.id];
      if (controller != null) {
        final newBudget = double.tryParse(controller.text.trim());
        if (newBudget != category.budget) {
          final updatedCategory = TransactionCategory(
            id: category.id,
            name: category.name,
            iconCodePoint: category.iconCodePoint,
            colorHex: category.colorHex,
            budget: newBudget == 0 ? null : newBudget,
          );
          notifier.editCategory(updatedCategory);
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Budgets updated successfully')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Manage Budgets'),
        actions: [
          TextButton(
            onPressed: _saveBudgets,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Gap(8),
        ],
      ),
      body: categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: AppTheme.textLightColor(context).withValues(alpha: 0.2)),
                  const Gap(16),
                  const Text('No categories found to set budgets'),
                ],
              ),
            )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                if (!_controllers.containsKey(category.id)) {
                  _controllers[category.id] = TextEditingController(
                    text: category.budget?.toString() ?? '',
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.dividerColor(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                          color: category.color,
                          size: 24,
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Monthly Budget',
                              style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _controllers[category.id],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixText: currency.symbol,
                            hintText: '0.00',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.dividerColor(context)),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.dividerColor(context)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.primaryColor(context), width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
