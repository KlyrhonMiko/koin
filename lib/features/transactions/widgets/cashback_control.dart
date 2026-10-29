import 'package:flutter/material.dart';
import 'package:koin/core/core.dart';

class CashbackControl extends StatelessWidget {
  const CashbackControl({
    super.key,
    required this.amount,
    required this.currency,
    required this.rule,
    required this.onRuleChanged,
  });

  final double amount;
  final Currency currency;
  final CashbackRule rule;
  final ValueChanged<CashbackRule> onRuleChanged;

  String _label(CashbackRule value) => switch (value) {
    CashbackRule.none => 'None',
    CashbackRule.onePercent => '1%',
    CashbackRule.fixedFive => '${currency.symbol}5',
  };

  @override
  Widget build(BuildContext context) => Tooltip(
    message: rule == CashbackRule.none
        ? 'Add cashback'
        : 'Cashback ${_label(rule)} · ${currency.formatter.format(rule.calculate(amount))}',
    child: TextButton(
      key: const ValueKey('cashback_button'),
      onPressed: () => _open(context),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (MediaQuery.textScalerOf(context).scale(11) > 16.5)
              const Icon(KoinIcons.money, size: 16)
            else
              Text(
                'Cashback',
                style: TextStyle(
                  fontSize: KoinTypography.small,
                  fontWeight: KoinTypography.supportingWeight,
                  color: AppTheme.textLightColor(context),
                ),
              ),
            const SizedBox(width: 6),
            if (rule == CashbackRule.none)
              const Icon(KoinIcons.plus, size: 12)
            else
              Text(
                _label(rule),
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: KoinTypography.small,
                  fontWeight: KoinTypography.titleWeight,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _open(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticService.light();
    var selected = rule;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceColor(context),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cashback',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Calculated from ${currency.formatter.format(amount)}',
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) => KoinChoiceControl(
                          compact: true,
                          vertical:
                              constraints.maxWidth < 260 ||
                              MediaQuery.textScalerOf(context).scale(14) > 21,
                          segments: [
                            const KoinSegmentItem(label: 'None'),
                            const KoinSegmentItem(label: '1%'),
                            KoinSegmentItem(label: '${currency.symbol}5 fixed'),
                          ],
                          selectedIndex: selected.index,
                          onChanged: (index) {
                            setState(
                              () => selected = CashbackRule.values[index],
                            );
                            onRuleChanged(selected);
                          },
                        ),
                      ),
                      if (selected != CashbackRule.none) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Cashback · ${currency.formatter.format(selected.calculate(amount))}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Recorded as income when you save this transaction.',
                          style: TextStyle(
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      KoinPrimaryButton(
                        label: 'Done',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
