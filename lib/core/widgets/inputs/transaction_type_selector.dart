import 'package:flutter/material.dart';
import 'package:koin/core/widgets/primitives/koin_segmented_control.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/theme.dart';

class TransactionTypeSelector extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onChanged;
  final Color activeColor;
  final List<TransactionType>? allowedTypes;

  const TransactionTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
    required this.activeColor,
    this.allowedTypes,
  });

  List<TransactionType> get _effectiveTypes =>
      allowedTypes ??
      const [
        TransactionType.expense,
        TransactionType.income,
        TransactionType.transfer,
      ];

  @override
  Widget build(BuildContext context) {
    final allTypes = [
      (
        'Expense',
        TransactionType.expense,
        AppTheme.expenseColor(context),
        Icons.arrow_upward_rounded,
      ),
      (
        'Income',
        TransactionType.income,
        AppTheme.incomeColor(context),
        Icons.arrow_downward_rounded,
      ),
      (
        'Transfer',
        TransactionType.transfer,
        AppTheme.transferColor(context),
        Icons.swap_horiz_rounded,
      ),
    ];

    final types = allTypes
        .where((t) => _effectiveTypes.contains(t.$2))
        .toList();

    final selectedIndex = types.indexWhere((type) => type.$2 == selectedType);
    return KoinChoiceControl(
      segments: [
        for (final type in types)
          KoinSegmentItem(label: type.$1, icon: type.$4),
      ],
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onChanged: (index) => onChanged(types[index].$2),
    );
  }
}
