import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    _amountController = TextEditingController(
      text: widget.goal?.targetAmount.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.goal?.notes ?? '');
    _startDate = widget.goal?.startDate ?? DateTime.now();
    _endDate =
        widget.goal?.endDate ?? DateTime.now().add(const Duration(days: 30));
    _selectedAccountId = widget.goal?.linkedAccountId;
    _isStash = widget.goal?.isStash ?? false;
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      KoinSnackBar.error(
        context,
        'Name required',
        subtitle: 'Please enter a name for your savings goal',
      );
      return;
    }

    final targetAmount = double.tryParse(_amountController.text);
    if (!_isStash && (targetAmount == null || targetAmount <= 0)) {
      KoinSnackBar.error(
        context,
        'Invalid amount',
        subtitle: 'Target amount must be greater than zero for goals',
      );
      return;
    }

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
  Widget build(BuildContext context) {
    final isEditing = widget.goal != null;
    final primaryColor = AppTheme.primaryColor(context);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final accountsAsync = ref.watch(accountProvider);
    final accounts = accountsAsync.asData?.value ?? [];
    final goalsAsync = ref.watch(computedSavingsGoalsProvider);
    final goals = goalsAsync.asData?.value ?? [];

    final linkedAccountIds = goals
        .where((g) => g.id != widget.goal?.id && g.linkedAccountId != null)
        .map((g) => g.linkedAccountId!)
        .toSet();

    final availableAccounts = accounts
        .where((a) => !linkedAccountIds.contains(a.id))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Column(
        children: [
          _buildHeader(context, currency, primaryColor),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline
                    const FormSectionTitle.subhead(title: 'Timeline'),
                    const Gap(12),
                    Row(
                          children: [
                            Expanded(
                              child: DateSelectorTile(
                                label: 'Start Date',
                                date: _startDate,
                                icon: Icons.play_arrow_rounded,
                                onTap: () => _selectDate(context, true),
                              ),
                            ),
                            if (!_isStash) ...[
                              const Gap(12),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLightColor(context),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: AppTheme.textLightColor(context),
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: DateSelectorTile(
                                  label: 'Target Date',
                                  date: _endDate,
                                  icon: Icons.flag_rounded,
                                  onTap: () => _selectDate(context, false),
                                ),
                              ),
                            ],
                          ],
                        )
                        .animate()
                        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    if (!_isStash && _amountController.text.isNotEmpty) ...[
                      const Gap(12),
                      Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  size: 18,
                                  color: primaryColor,
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Text(
                                    'Save ${_getDailyEstimate()}/day to reach your goal in $_totalDays days',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                          .scale(
                            begin: const Offset(0.95, 0.95),
                            duration: 250.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      const Gap(32),
                    ] else ...[
                      const Gap(32),
                    ],

                    // Additional Details
                    const FormSectionTitle.subhead(title: 'Details'),
                    const Gap(12),

                    // Linked Account
                    SelectionTile(
                          fallbackIcon: Icons.account_balance_wallet_rounded,
                          label: 'Linked Account (Optional)',
                          selectedName: _accountById(
                            accounts,
                            _selectedAccountId,
                          )?.name,
                          selectedColor: _accountById(
                            accounts,
                            _selectedAccountId,
                          )?.color,
                          selectedIconCodePoint: _accountById(
                            accounts,
                            _selectedAccountId,
                          )?.iconCodePoint,
                          selectedLogoAsset: _accountById(
                            accounts,
                            _selectedAccountId,
                          )?.logoAsset,
                          placeholder: 'None',
                          onTap: () => _openAccountPicker(
                            context,
                            availableAccounts,
                            title: 'Linked Account',
                            subtitle: 'Link an account to fund this goal',
                            selectedId: _selectedAccountId,
                            onSelected: (id) =>
                                setState(() => _selectedAccountId = id),
                          ),
                        )
                        .animate()
                        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const Gap(16),

                    // Notes
                    Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppTheme.dividerColor(
                                context,
                              ).withValues(alpha: 0.7),
                            ),
                            boxShadow: [
                              AppTheme.boxShadow(
                                context,
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLightColor(context),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.sticky_note_2_rounded,
                                    size: 17,
                                    color: AppTheme.textLightColor(context),
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: TextField(
                                    controller: _notesController,
                                    onTap: () {
                                      HapticService.light();
                                    },
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.textColor(context),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Notes (Optional)',
                                      hintStyle: TextStyle(
                                        color: AppTheme.textLightColor(
                                          context,
                                        ).withValues(alpha: 0.45),
                                        fontWeight: FontWeight.w400,
                                        fontSize: 15,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: KoinPrimaryButton(
                  label: isEditing ? 'Update Goal' : 'Create Goal',
                  onPressed: _save,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              )
              .animate()
              .fade(duration: 250.ms, curve: Curves.easeOutCubic)
              .scale(
                begin: const Offset(0.95, 0.95),
                duration: 250.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Currency currency,
    Color primaryColor,
  ) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor(context),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Gap(topPadding + 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [KoinBackButton(), Spacer()]),
          ),
          const Gap(8),

          // Goal Name Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                hintText: 'Name your goal',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.4),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          const Gap(4),

          // Target Amount Input
          HeroAmountField(
            controller: _amountController,
            currencySymbol: currency.symbol,
            primaryColor: primaryColor,
            onChanged: (_) => setState(() {}),
          ),

          const Gap(16),
          // Stash Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isStash
                    ? primaryColor.withValues(alpha: 0.1)
                    : AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isStash
                      ? primaryColor.withValues(alpha: 0.3)
                      : AppTheme.dividerColor(context).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isStash
                          ? primaryColor.withValues(alpha: 0.2)
                          : AppTheme.surfaceLightColor(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.savings_rounded,
                      size: 18,
                      color: _isStash
                          ? primaryColor
                          : AppTheme.textLightColor(context),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stash Mode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _isStash
                                ? primaryColor
                                : AppTheme.textColor(context),
                          ),
                        ),
                        Text(
                          'Save without a strict target or date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isStash,
                    onChanged: (val) {
                      HapticService.light();
                      setState(() => _isStash = val);
                    },
                    activeTrackColor: primaryColor.withValues(alpha: 0.5),
                    activeThumbColor: primaryColor,
                  ),
                ],
              ),
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // Selection Row
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // Picker helper methods
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
