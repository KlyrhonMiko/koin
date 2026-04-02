import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/models/account.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/widgets/koin_back_button.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    HapticService.light();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryColor(context),
              onPrimary: Colors.white,
              surface: AppTheme.surfaceColor(context),
              onSurface: AppTheme.textColor(context),
            ),
          ),
          child: child!,
        );
      },
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
    if (_nameController.text.trim().isEmpty) {
      HapticService.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a goal name'),
          backgroundColor: AppTheme.errorColor(context),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      HapticService.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: AppTheme.errorColor(context),
        ),
      );
      return;
    }

    final goal = SavingsGoal(
      id: widget.goal?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      targetAmount: amount,
      currentAmount: widget.goal?.currentAmount ?? 0.0,
      startDate: _startDate,
      endDate: _endDate,
      notes: _notesController.text.trim(),
      linkedAccountId: _selectedAccountId,
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
    if (amount == null || amount <= 0 || _totalDays <= 0) return '—';
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
                    _buildSectionTitle(context, 'Timeline'),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateSelector(
                            context,
                            label: 'Start Date',
                            date: _startDate,
                            icon: Icons.play_arrow_rounded,
                            onTap: () => _selectDate(context, true),
                          ),
                        ),
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
                          child: _buildDateSelector(
                            context,
                            label: 'Target Date',
                            date: _endDate,
                            icon: Icons.flag_rounded,
                            onTap: () => _selectDate(context, false),
                          ),
                        ),
                      ],
                    ).animate().fade(delay: 50.ms).slideY(begin: 0.1),
                    const Gap(12),
                    // Daily estimate card
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
                    ).animate().fade(delay: 100.ms).slideY(begin: 0.1),
                    const Gap(32),

                    // Additional Details
                    _buildSectionTitle(context, 'Details'),
                    const Gap(12),

                    // Linked Account
                    _buildSelectionRow(
                      context,
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
                    ).animate().fade(delay: 150.ms).slideY(begin: 0.1),
                    const Gap(16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Add any notes about this goal...',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        filled: true,
                        fillColor: AppTheme.surfaceColor(context),
                      ),
                      maxLines: 3,
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: PressableScale(
          onTap: _save,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppTheme.primaryGradient(context),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              isEditing ? 'Update Goal' : 'Create Goal',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textLightColor(context),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic currency,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${currency.symbol} ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
              ),
              IntrinsicWidth(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: _amountController.text.isEmpty
                        ? primaryColor.withValues(alpha: 0.35)
                        : primaryColor,
                    letterSpacing: -2,
                    height: 1.1,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(
                      color: primaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          // Little subtle animated underline
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _amountController.text.isNotEmpty ? 60 : 40,
            height: 3,
            margin: const EdgeInsets.only(top: 8, bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: primaryColor.withValues(
                alpha: _amountController.text.isNotEmpty ? 0.35 : 0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(
    BuildContext context, {
    required String label,
    required DateTime date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.6),
                ),
                const Gap(6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              DateFormat.yMMMd().format(date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Selection Row
  // ═══════════════════════════════════════════════════════
  Widget _buildSelectionRow(
    BuildContext context, {
    required IconData fallbackIcon,
    required String label,
    required String? selectedName,
    required Color? selectedColor,
    required int? selectedIconCodePoint,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasSelection =
        selectedName != null &&
        selectedColor != null &&
        selectedIconCodePoint != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService.light();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? selectedColor.withValues(alpha: 0.12)
                        : AppTheme.surfaceLightColor(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasSelection
                        ? IconUtils.getIcon(selectedIconCodePoint)
                        : fallbackIcon,
                    size: 17,
                    color: hasSelection
                        ? selectedColor
                        : AppTheme.textLightColor(context),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.65),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        hasSelection ? selectedName : placeholder,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasSelection
                              ? AppTheme.textColor(context)
                              : AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Picker helper methods
  // ═══════════════════════════════════════════════════════
  Future<void> _openAccountPicker(
    BuildContext context,
    List<Account> accounts, {
    required String title,
    required String subtitle,
    required String? selectedId,
    required void Function(String?) onSelected,
  }) async {
    final id = await _showPremiumSelectionSheet<String>(
      context: context,
      title: title,
      subtitle: subtitle,
      itemCount: accounts.length + 1, // +1 for "None"
      itemBuilder: (context, index) {
        if (index == 0) {
          return _PremiumSheetItem(
            name: 'No Linked Account',
            accentColor: AppTheme.textLightColor(context),
            iconCodePoint: Icons.link_off_rounded.codePoint,
            selected: selectedId == null,
            onTap: () =>
                Navigator.pop(context, ''), // empty string represents None
          );
        }
        final acc = accounts[index - 1];
        return _PremiumSheetItem(
          name: acc.name,
          accentColor: acc.color,
          iconCodePoint: acc.iconCodePoint,
          selected: acc.id == selectedId,
          onTap: () => Navigator.pop(context, acc.id),
        );
      },
    );
    if (id != null) {
      if (mounted) {
        onSelected(id.isEmpty ? null : id);
      }
    }
  }

  Future<T?> _showPremiumSelectionSheet<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    final primaryColor = AppTheme.primaryColor(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(sheetContext).padding.top + 12,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(sheetContext),
                  border: Border.all(
                    color: AppTheme.dividerColor(sheetContext),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(10),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor(sheetContext),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const Gap(10),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: AppTheme.textColor(sheetContext),
                                ),
                              ),
                            ],
                          ),
                          const Gap(4),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                                color: AppTheme.textLightColor(sheetContext),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16 + bottomInset,
                        ),
                        itemCount: itemCount,
                        separatorBuilder: (context, index) => const Gap(8),
                        itemBuilder: (context, index) {
                          return itemBuilder(context, index)
                              .animate()
                              .fadeIn(delay: (index * 40).ms, duration: 250.ms)
                              .slideX(
                                begin: 0.04,
                                duration: 250.ms,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PremiumSheetItem extends StatelessWidget {
  const _PremiumSheetItem({
    required this.name,
    required this.accentColor,
    required this.iconCodePoint,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color accentColor;
  final int iconCodePoint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.45)
                  : AppTheme.dividerColor(context).withValues(alpha: 0.65),
              width: selected ? 1.5 : 1,
            ),
            color: selected
                ? primary.withValues(alpha: 0.08)
                : AppTheme.surfaceLightColor(context).withValues(alpha: 0.45),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconUtils.getIcon(iconCodePoint),
                  color: accentColor,
                  size: 22,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primary, size: 26)
              else
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.dividerColor(context),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
