import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
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

  int get _typeIndex {
    final idx = _effectiveTypes.indexOf(selectedType);
    return idx != -1 ? idx : 0;
  }

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

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.6),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / types.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
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
                      AppTheme.boxShadow(
                        context,
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: types.map((t) {
                  final isSelected = selectedType == t.$2;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(t.$2),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              t.$4,
                              size: 15,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textLightColor(context),
                            ),
                            const Gap(5),
                            Text(
                              t.$1,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textLightColor(context),
                                fontWeight: KoinTypography.titleWeight,
                                fontSize: KoinTypography.caption,
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
}
