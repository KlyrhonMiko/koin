import 'package:koin/core/icons.dart';
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
        KoinIcons.arrowUp,
      ),
      (
        'Income',
        TransactionType.income,
        AppTheme.incomeColor(context),
        KoinIcons.arrowDown,
      ),
      (
        'Transfer',
        TransactionType.transfer,
        AppTheme.transferColor(context),
        KoinIcons.arrowsLeftRight,
      ),
    ];

    final types = allTypes
        .where((t) => _effectiveTypes.contains(t.$2))
        .toList();

    final selectedIndex = types.indexWhere((type) => type.$2 == selectedType);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final widestLabel = types.fold<double>(0, (width, type) {
          final painter = TextPainter(
            text: TextSpan(
              text: type.$1,
              style: DefaultTextStyle.of(context).style
                  .merge(KoinTypography.choiceLabelStyle),
            ),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
          )..layout();
          final labelWidth = painter.width;
          painter.dispose();
          return labelWidth > width ? labelWidth : width;
        });
        final segmentWidth =
            (constraints.maxWidth - types.length + 1) / types.length;
        final vertical = segmentWidth < widestLabel + 16;
        final showIcons = vertical || segmentWidth >= widestLabel + 38;
        return KoinChoiceControl(
          compact: true,
          vertical: vertical,
          segments: [
            for (final type in types)
              KoinSegmentItem(label: type.$1, icon: showIcons ? type.$4 : null),
          ],
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          onChanged: (index) => onChanged(types[index].$2),
        );
      },
    );
  }
}
