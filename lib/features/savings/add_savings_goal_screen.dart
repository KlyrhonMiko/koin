import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';

class AddSavingsGoalScreen extends ConsumerStatefulWidget {
  final SavingsGoal? goal;

  const AddSavingsGoalScreen({super.key, this.goal});

  @override
  ConsumerState<AddSavingsGoalScreen> createState() =>
      _AddSavingsGoalScreenState();
}

class _AddSavingsGoalScreenState extends ConsumerState<AddSavingsGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedAccountId;
  late bool _isStash;
  late bool _includeInDashboardBalance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    _amountController = TextEditingController(
      text: widget.goal?.targetAmount?.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.goal?.notes ?? '');
    _startDate = widget.goal?.startDate ?? DateTime.now();
    _endDate =
        widget.goal?.endDate ?? DateTime.now().add(const Duration(days: 30));
    _selectedAccountId = widget.goal?.linkedAccountId;
    _isStash = widget.goal?.isStash ?? false;
    _includeInDashboardBalance = widget.goal?.includeInDashboardBalance ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showThemedDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate.subtract(const Duration(days: 1));
          }
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final targetAmount = double.tryParse(_amountController.text);

    final goal = SavingsGoal(
      id: widget.goal?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      targetAmount: _isStash && (targetAmount == null || targetAmount <= 0)
          ? null
          : (targetAmount ?? 0.0),
      currentAmount: widget.goal?.currentAmount ?? 0.0,
      startDate: _startDate,
      endDate: _isStash ? null : _endDate,
      notes: _notesController.text.trim(),
      linkedAccountId: _selectedAccountId,
      isStash: _isStash,
      includeInDashboardBalance: _includeInDashboardBalance,
    );

    if (widget.goal == null) {
      ref.read(savingsGoalsProvider.notifier).addGoal(goal);
    } else {
      ref.read(savingsGoalsProvider.notifier).updateGoal(goal);
    }

    HapticService.success();
    Navigator.pop(context);
  }

  int get _totalDays => _endDate.difference(_startDate).inDays;

  String _getDailyEstimate() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || _totalDays <= 0) return 'â€”';
    final settings = ref.read(settingsProvider);
    final fmt = NumberFormat.simpleCurrency(name: settings.currency.code);
    return fmt.format(amount / _totalDays);
  }

  Account? _accountById(List<Account> list, String? id) {
    if (id == null) return null;
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => KoinFormTheme(builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final isEditing = widget.goal != null;
    final isStash = _isStash;
    final primaryColor = AppTheme.primaryColor(context);
    final currency = ref.watch(settingsProvider).currency;
    final accounts = ref.watch(accountProvider).asData?.value ?? [];
    final goals = ref.watch(computedSavingsGoalsProvider).asData?.value ?? [];
    final linkedAccountIds = goals
        .where((g) => g.id != widget.goal?.id && g.linkedAccountId != null)
        .map((g) => g.linkedAccountId!)
        .toSet();
    final availableAccounts = accounts
        .where((a) => !linkedAccountIds.contains(a.id))
        .toList();
    final linkedAccount = _accountById(accounts, _selectedAccountId);
    final amount = double.tryParse(_amountController.text);
    final showEstimate =
        !_isStash && amount != null && amount > 0 && _totalDays > 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: KoinBackButton(),
        ),
        title: Text(isEditing ? 'Edit goal' : 'New goal'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Gap(12),
                        TextFormField(
                          key: const Key('goal_name'),
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor(context),
                            letterSpacing: -0.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Name your goal',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            hintStyle: TextStyle(
                              color: AppTheme.fieldHintColor(
                                context,
                                lightOpacity: 0.4,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a name for your goal'
                              : null,
                        ),
                        const Gap(16),
                        Text(
                          _isStash
                              ? 'Target amount (optional)'
                              : 'Target amount',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textLightColor(context),
                              ),
                        ),
                        HeroAmountField(
                          fieldKey: const Key('goal_amount'),
                          controller: _amountController,
                          currencySymbol: currency.symbol,
                          primaryColor: primaryColor,
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (_isStash &&
                                (value == null || value.trim().isEmpty)) {
                              return null;
                            }
                            final target = double.tryParse(value ?? '');
                            return target == null ||
                                    !target.isFinite ||
                                    target <= 0
                                ? 'Enter an amount greater than zero'
                                : null;
                          },
                        ),
                        const Gap(12),
                        _fieldLabel(context, 'Saving plan'),
                        const Gap(8),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.flag_rounded),
                              label: Text('Goal'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.savings_rounded),
                              label: Text('Stash'),
                            ),
                          ],
                          selected: {_isStash},
                          showSelectedIcon: false,
                          expandedInsets: EdgeInsets.zero,
                          style: ButtonStyle(
                            minimumSize: const WidgetStatePropertyAll(
                              Size(0, 48),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? primaryColor.withValues(alpha: 0.14)
                                  : AppTheme.surfaceColor(context),
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              AppTheme.textColor(context),
                            ),
                            side: WidgetStatePropertyAll(
                              BorderSide(
                                color: AppTheme.fieldBorderColor(context),
                              ),
                            ),
                          ),
                          onSelectionChanged: (selection) {
                            HapticService.light();
                            setState(() => _isStash = selection.single);
                          },
                        ),
                        const Gap(8),
                        Text(
                          _isStash
                              ? 'Save at your own pace. Amount is optional; no deadline.'
                              : 'Choose an amount and a date to work toward.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textLightColor(context),
                              ),
                        ),
                        const Gap(24),
                        _fieldLabel(
                          context,
                          _isStash ? 'Start date' : 'Timeline',
                        ),
                        const Gap(8),
                        _revealFields(
                          context,
                          child: LayoutBuilder(
                            key: ValueKey(_isStash),
                            builder: (context, constraints) {
                              final start = DateSelectorTile(
                                label: 'Start date',
                                date: _startDate,
                                onTap: () => _selectDate(context, true),
                              );
                              if (isStash) return start;
                              final end = DateSelectorTile(
                                label: 'Target date',
                                date: _endDate,
                                icon: Icons.flag_rounded,
                                onTap: () => _selectDate(context, false),
                              );
                              if (constraints.maxWidth < 340 ||
                                  MediaQuery.textScalerOf(context).scale(16) >
                                      20) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [start, const Gap(12), end],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: start),
                                  const Gap(12),
                                  Expanded(child: end),
                                ],
                              );
                            },
                          ),
                        ),
                        _revealFields(
                          context,
                          delay: const Duration(milliseconds: 40),
                          child: showEstimate
                              ? Column(
                                  key: const ValueKey('daily_estimate'),
                                  children: [
                                    const Gap(12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.insights_rounded,
                                          size: 18,
                                          color: primaryColor,
                                        ),
                                        const Gap(8),
                                        Expanded(
                                          child: Text(
                                            'About ${_getDailyEstimate()} a day over $_totalDays days.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      AppTheme.textLightColor(
                                                        context,
                                                      ),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('no_estimate'),
                                ),
                        ),
                        const Gap(28),
                        Divider(
                          color: AppTheme.dividerColor(context),
                          height: 1,
                        ),
                        const Gap(24),
                        _fieldLabel(context, 'Optional details'),
                        const Gap(12),
                        KoinGroupedCard(
                          autoDivide: false,
                          borderRadius: 16,
                          borderColor: AppTheme.fieldBorderColor(context),
                          children: [
                            SelectionTile(
                              asCard: false,
                              fallbackIcon:
                                  Icons.account_balance_wallet_rounded,
                              label: 'Linked account',
                              selectedName: linkedAccount?.name,
                              selectedColor: linkedAccount?.color,
                              selectedIconCodePoint:
                                  linkedAccount?.iconCodePoint,
                              selectedLogoAsset: linkedAccount?.logoAsset,
                              placeholder: 'Choose an account',
                              onTap: () => _openAccountPicker(
                                context,
                                availableAccounts,
                                title: 'Linked Account',
                                subtitle: 'Link an account to fund this goal',
                                selectedId: _selectedAccountId,
                                onSelected: (id) =>
                                    setState(() => _selectedAccountId = id),
                              ),
                            ),
                            _revealFields(
                              context,
                              child: _selectedAccountId == null
                                  ? const SizedBox.shrink(
                                      key: ValueKey('no_dashboard_option'),
                                    )
                                  : Column(
                                      key: const ValueKey('dashboard_option'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Divider(
                                          height: 1,
                                          indent: 16,
                                          endIndent: 16,
                                          color: AppTheme.fieldBorderColor(
                                            context,
                                          ),
                                        ),
                                        SwitchListTile.adaptive(
                                          key: const ValueKey(
                                            'include_in_dashboard',
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 4,
                                              ),
                                          title: const Text(
                                            'Include in balances',
                                            style: TextStyle(
                                              fontSize: KoinTypography.compact,
                                              fontWeight:
                                                  KoinTypography.labelWeight,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Show in dashboard and account balances',
                                            style: TextStyle(
                                              fontSize: KoinTypography.caption,
                                              color: AppTheme.textLightColor(
                                                context,
                                              ),
                                            ),
                                          ),
                                          value: _includeInDashboardBalance,
                                          onChanged: (value) => setState(
                                            () => _includeInDashboardBalance =
                                                value,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        const Gap(20),
                        _fieldLabel(context, 'Notes'),
                        const Gap(8),
                        TextFormField(
                          key: const Key('goal_notes'),
                          controller: _notesController,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'What are you saving for?',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: KoinPrimaryButton(
                  label: isEditing
                      ? (_isStash ? 'Update Stash' : 'Update Goal')
                      : (_isStash ? 'Create Stash' : 'Create Goal'),
                  onPressed: _save,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String label) => Text(
    label,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: AppTheme.textColor(context),
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _revealFields(
    BuildContext context, {
    required Widget child,
    Duration delay = Duration.zero,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    const duration = Duration(milliseconds: 250);

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration + delay,
        reverseDuration: duration,
        switchInCurve: Interval(
          delay.inMilliseconds / (duration + delay).inMilliseconds,
          1,
          curve: Curves.easeOutCubic,
        ),
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        // Outgoing fields remain visible for their exit, without holding open
        // the layout or accepting taps after the saving plan has changed.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final previous in previousChildren)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: ExcludeSemantics(child: previous)),
              ),
            ?currentChild,
          ],
        ),
        child: child,
      ),
    );
  }

  Future<void> _openAccountPicker(
    BuildContext context,
    List<Account> accounts, {
    required String title,
    required String subtitle,
    required String? selectedId,
    required void Function(String?) onSelected,
  }) async {
    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: selectedId,
      title: title,
      subtitle: subtitle,
      allowNone: true,
      noneLabel: 'No Linked Account',
      accountsOverride: accounts,
    );
    if (id != null && mounted) {
      onSelected(id.isEmpty ? null : id);
    }
  }
}
