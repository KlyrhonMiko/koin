import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/models/savings/savings_projection.dart';
import 'savings_projection_view.dart';

class SavingsPlanEditResult {
  final SavingsPlan? plan;
  final DateTime? deadline;
  final double? targetAmount;
  const SavingsPlanEditResult(this.plan, {this.deadline, this.targetAmount});
}

class SavingsPlanEditor extends ConsumerStatefulWidget {
  final SavingsPlan? initial;
  final SavingsGoal? goal;
  const SavingsPlanEditor({super.key, this.initial, this.goal});

  static Future<SavingsPlanEditResult?> open(
    BuildContext context, {
    SavingsPlan? initial,
    SavingsGoal? goal,
  }) => Navigator.push<SavingsPlanEditResult>(
    context,
    MaterialPageRoute(
      builder: (_) => SavingsPlanEditor(initial: initial, goal: goal),
    ),
  );

  @override
  ConsumerState<SavingsPlanEditor> createState() => _SavingsPlanEditorState();
}

class _SavingsPlanEditorState extends ConsumerState<SavingsPlanEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late SavingsFrequency _frequency;
  late DateTime _date;
  DateTime? _deadline;
  bool _showTargetAmount = false;
  bool _showSchedule = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.initial?.amount.toStringAsFixed(2) ?? '200',
    );
    _frequency = widget.initial?.frequency ?? SavingsFrequency.weekly;
    _date = widget.initial?.startDate ?? SavingsPlan.day(DateTime.now());
    _deadline = widget.goal?.isStash == false ? widget.goal?.endDate : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickFrequency() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showModalBottomSheet<SavingsFrequency>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    key: const ValueKey('frequency_picker'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const KoinBottomSheetHandle(),
                      const SizedBox(height: 12),
                      Text(
                        'How often?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      for (final frequency in SavingsFrequency.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            key: ValueKey('frequency_${frequency.name}'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: frequency == _frequency,
                            selectedTileColor: AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.08),
                            textColor: AppTheme.textColor(context),
                            selectedColor: AppTheme.textColor(context),
                            title: Text(frequency.label),
                            trailing: frequency == _frequency
                                ? Icon(
                                    Icons.check_rounded,
                                    color: AppTheme.primaryColor(context),
                                  )
                                : null,
                            onTap: () {
                              HapticService.selection();
                              Navigator.pop(context, frequency);
                            },
                          ),
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
    if (selected != null && mounted) setState(() => _frequency = selected);
  }

  Widget _previewTransition(BuildContext context, {required Widget child}) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: child,
    );
  }

  InputDecoration _fieldDecoration(BuildContext context, {String? prefix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      filled: true,
      fillColor: AppTheme.surfaceColor(context),
      prefixText: prefix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: AppTheme.primaryColor(context),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: TextStyle(
        fontSize: KoinTypography.caption,
        fontWeight: KoinTypography.labelWeight,
        color: AppTheme.textLightColor(context),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.simpleCurrency(
      name: ref.watch(settingsProvider).currency.code,
    );
    final logsAsync = widget.goal == null
        ? null
        : ref.watch(savingsLogsProvider(widget.goal!.id));
    final logs = logsAsync?.asData?.value ?? <SavingsLog>[];
    final amount = double.tryParse(_amount.text);
    final valid = amount != null && amount.isFinite && amount >= 0.01;
    final base =
        widget.goal ??
        SavingsGoal(
          id: 'helper-preview',
          name: 'Savings',
          startDate: _date,
          isStash: true,
        );
    final preview = base.copyWith(
      endDate: _deadline,
      clearSavingsPlan: !valid,
      savingsPlan: valid
          ? SavingsPlan(amount: amount, frequency: _frequency, startDate: _date)
          : null,
    );
    final requiredAmount =
        !valid ||
            _deadline == null ||
            logsAsync?.hasError == true ||
            logsAsync?.isLoading == true
        ? null
        : SavingsProjection(
            goal: preview,
            today: DateTime.now(),
            logs: logs,
          ).requiredBy(_deadline!);
    return KoinFormTheme(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Savings Helper')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: KoinPrimaryButton(
                  label: 'Save plan',
                  onPressed: () {
                    if (!_form.currentState!.validate()) return;
                    Navigator.pop(
                      context,
                      SavingsPlanEditResult(
                        SavingsPlan(
                          amount: double.parse(_amount.text),
                          frequency: _frequency,
                          startDate: _date,
                        ),
                        deadline: _deadline != widget.goal?.endDate
                            ? _deadline
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _fieldLabel(context, 'Amount to set aside'),
                    TextFormField(
                      key: const Key('plan_amount'),
                      controller: _amount,
                      style: Theme.of(context).textTheme.bodyLarge,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _fieldDecoration(
                        context,
                        prefix: '${format.currencySymbol} ',
                      ),
                      validator: (text) {
                        final value = double.tryParse(text ?? '');
                        return value == null || !value.isFinite || value < 0.01
                            ? 'Enter an amount of at least 0.01'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel(context, 'How often?'),
                    Semantics(
                      button: true,
                      label: 'How often?',
                      value: _frequency.label,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const ValueKey('frequency_field'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickFrequency,
                          child: InputDecorator(
                            decoration: _fieldDecoration(context),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _frequency.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.keyboard_arrow_down_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _previewTransition(
                      context,
                      child: !valid
                          ? const Text(
                              'Enter an amount to see your projection.',
                            )
                          : logsAsync?.isLoading == true
                          ? const LinearProgressIndicator()
                          : logsAsync?.hasError == true
                          ? Column(
                              children: [
                                const Text(
                                  'Could not load your savings activity.',
                                ),
                                TextButton(
                                  onPressed: () => ref.invalidate(
                                    savingsLogsProvider(widget.goal!.id),
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SavingsProjectionView(
                                  goal: preview,
                                  logs: logs,
                                  format: format,
                                  editorPreview: true,
                                ),
                                if (requiredAmount != null) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      key: const ValueKey(
                                        'show_deadline_amount',
                                      ),
                                      onPressed: () => setState(
                                        () => _showTargetAmount =
                                            !_showTargetAmount,
                                      ),
                                      child: Text(
                                        'Reach it by ${DateFormat.yMMMd().format(_deadline!)} instead',
                                      ),
                                    ),
                                  ),
                                  _previewTransition(
                                    context,
                                    child: !_showTargetAmount
                                        ? const SizedBox.shrink()
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Set aside ${format.format(requiredAmount)} ${contributionPhrase(_frequency)}.',
                                              ),
                                              TextButton(
                                                key: const ValueKey(
                                                  'use_deadline_amount',
                                                ),
                                                onPressed: () => setState(() {
                                                  _amount.text = requiredAmount
                                                      .toStringAsFixed(2);
                                                  _showTargetAmount = false;
                                                }),
                                                child: const Text(
                                                  'Use this amount',
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton(
                          key: const ValueKey('helper_schedule'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textColor(context),
                            overlayColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _showSchedule = !_showSchedule);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Schedule options',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              AnimatedRotation(
                                turns: _showSchedule ? 0.5 : 0,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _previewTransition(
                          context,
                          child: !_showSchedule
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 16),
                                      DateSelectorTile(
                                        label: 'First contribution',
                                        date: _date,
                                        onTap: () async {
                                          final selected =
                                              await showThemedDatePicker(
                                                context: context,
                                                initialDate: _date,
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2101),
                                              );
                                          if (selected != null && mounted) {
                                            setState(() => _date = selected);
                                          }
                                        },
                                      ),
                                      if (_deadline != null) ...[
                                        const SizedBox(height: 12),
                                        DateSelectorTile(
                                          label: 'Reach goal by',
                                          date: _deadline!,
                                          onTap: () async {
                                            final selected =
                                                await showThemedDatePicker(
                                                  context: context,
                                                  initialDate: _deadline!,
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2101),
                                                );
                                            if (selected != null && mounted) {
                                              setState(
                                                () => _deadline = selected,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                      if (widget.initial != null)
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            const SavingsPlanEditResult(null),
                                          ),
                                          child: const Text('Remove plan'),
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
