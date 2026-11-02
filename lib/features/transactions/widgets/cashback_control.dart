import 'package:flutter/material.dart';
import 'package:koin/core/core.dart';
import 'package:intl/intl.dart';

class CashbackControl extends StatelessWidget {
  const CashbackControl({
    super.key,
    required this.amount,
    required this.currency,
    required this.rule,
    required this.onRuleChanged,
    this.pending = false,
    this.defaultPending = false,
    this.receivedAt,
    this.transactionDate,
    this.onReceived,
    this.onPending,
  });

  final double amount;
  final Currency currency;
  final CashbackRule rule;
  final ValueChanged<CashbackRule> onRuleChanged;
  final bool pending;
  final bool defaultPending;
  final DateTime? receivedAt;
  final DateTime? transactionDate;
  final ValueChanged<DateTime>? onReceived;
  final VoidCallback? onPending;

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
    var isPending = pending;
    var hasReceiptDate = receivedAt != null;
    final now = DateTime.now();
    var receiptDate = receivedAt ?? now;
    final firstDate = DateUtils.dateOnly(transactionDate ?? now);
    final today = DateUtils.dateOnly(now);
    final canReceive =
        !(transactionDate ?? now).isAfter(now) && onReceived != null;
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
                            setState(() {
                              selected = CashbackRule.values[index];
                              if (selected == CashbackRule.none) {
                                isPending = defaultPending;
                                hasReceiptDate = false;
                                receiptDate = DateTime.now();
                              }
                            });
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
                          isPending
                              ? 'Pending · Excluded from your balance and income.'
                              : 'Recorded as income when you save this transaction.',
                          style: TextStyle(
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                        if (isPending || hasReceiptDate) ...[
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final dateControl = TextButton(
                                key: const ValueKey('cashback_receipt_date'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.textColor(context),
                                  backgroundColor: AppTheme.surfaceLightColor(
                                    context,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(48, 64),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      KoinShape.field,
                                    ),
                                  ),
                                ),
                                onPressed: !canReceive
                                    ? null
                                    : () async {
                                        final picked =
                                            await showThemedDatePicker(
                                              context: context,
                                              initialDate:
                                                  receiptDate.isBefore(
                                                    firstDate,
                                                  )
                                                  ? firstDate
                                                  : receiptDate,
                                              firstDate: firstDate,
                                              lastDate: today,
                                            );
                                        if (picked == null ||
                                            !context.mounted) {
                                          return;
                                        }
                                        setState(() => receiptDate = picked);
                                        if (!isPending) onReceived!(picked);
                                      },
                                child: Row(
                                  children: [
                                    Icon(
                                      isPending
                                          ? KoinIcons.calendarBlank
                                          : KoinIcons.calendarCheck,
                                      size: 20,
                                      color: AppTheme.textLightColor(context),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isPending
                                                ? 'Receipt date'
                                                : 'Received',
                                            style: TextStyle(
                                              fontSize: KoinTypography.small,
                                              fontWeight: KoinTypography
                                                  .supportingWeight,
                                              color: AppTheme.textLightColor(
                                                context,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat.yMMMd().format(
                                              receiptDate,
                                            ),
                                            style: const TextStyle(
                                              fontSize: KoinTypography.compact,
                                              fontWeight:
                                                  KoinTypography.titleWeight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (!isPending && onPending == null) {
                                return dateControl;
                              }
                              final receiveControl = FilledButton.tonalIcon(
                                key: ValueKey(
                                  isPending
                                      ? 'cashback_mark_received'
                                      : 'cashback_mark_pending',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.12),
                                  foregroundColor: AppTheme.textColor(context),
                                  overlayColor: AppTheme.primaryColor(context),
                                  minimumSize: const Size(48, 64),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      KoinShape.field,
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: KoinTypography.fontFamily,
                                    fontSize: KoinTypography.compact,
                                    fontWeight: KoinTypography.titleWeight,
                                  ),
                                ),
                                onPressed: isPending
                                    ? !canReceive ||
                                              selected.calculate(amount) <= 0
                                          ? null
                                          : () {
                                              onReceived!(receiptDate);
                                              setState(() {
                                                isPending = false;
                                                hasReceiptDate = true;
                                              });
                                            }
                                    : () {
                                        onPending!();
                                        setState(() {
                                          isPending = true;
                                          hasReceiptDate = false;
                                        });
                                      },
                                icon: Icon(
                                  isPending ? KoinIcons.check : KoinIcons.clock,
                                  size: 18,
                                ),
                                label: Text(
                                  isPending ? 'Mark received' : 'Mark pending',
                                ),
                              );
                              if (constraints.maxWidth < 340 ||
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      18) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    dateControl,
                                    const SizedBox(height: 10),
                                    receiveControl,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: dateControl),
                                  const SizedBox(width: 10),
                                  receiveControl,
                                ],
                              );
                            },
                          ),
                        ],
                        if (isPending) ...[
                          if (!canReceive)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Mark received on or after the transaction date.',
                                style: TextStyle(
                                  color: AppTheme.textLightColor(context),
                                ),
                              ),
                            ),
                          if (canReceive && selected.calculate(amount) <= 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Cashback must be above zero to mark it received.',
                                style: TextStyle(
                                  color: AppTheme.textLightColor(context),
                                ),
                              ),
                            ),
                        ],
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
