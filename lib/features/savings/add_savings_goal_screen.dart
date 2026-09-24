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
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/core/models/account.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/widgets/select_sheet.dart';
import 'package:koin/core/widgets/account_item.dart';
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
    final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocus) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!context.mounted) return;
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      KoinSnackBar.error(
        context,
        'Name required',
        subtitle: 'Please enter a name for your savings goal',
      );
      return;
    }

    final targetAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (targetAmount <= 0) {
      KoinSnackBar.error(
        context,
        'Invalid amount',
        subtitle: 'Target amount must be greater than zero',
      );
      return;
    }

    final goal = SavingsGoal(
      id: widget.goal?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      targetAmount: targetAmount,
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
                    if (_amountController.text.isNotEmpty) ...[
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
                      ).animate().fade(delay: 100.ms).slideY(begin: 0.1),
                      const Gap(32),
                    ] else ...[
                      const Gap(32),
                    ],

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
                    ).animate().fade(delay: 150.ms).slideY(begin: 0.1),
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
                          BoxShadow(
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
      onTap: () async {
        final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
        FocusManager.instance.primaryFocus?.unfocus();
        if (hadFocus) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
        onTap();
      },
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // Selection Row
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildSelectionRow(
    BuildContext context, {
    required IconData fallbackIcon,
    required String label,
    required String? selectedName,
    required Color? selectedColor,
    required int? selectedIconCodePoint,
    String? selectedLogoAsset,
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
          onTap: () async {
            HapticService.light();
            final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
            FocusManager.instance.primaryFocus?.unfocus();
            if (hadFocus) {
              await Future.delayed(const Duration(milliseconds: 150));
            }
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Builder(builder: (context) {

                if (hasSelection && selectedLogoAsset != null && selectedLogoAsset.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      selectedLogoAsset,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  );
                }

                  return Container(
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
                );

                }),
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
    final stats = ref.read(dashboardStatsProvider);
    final currency = ref.read(settingsProvider).currency;
    final id = await showSelectSheet<String>(
      context: context,
      title: title,
      subtitle: subtitle,
      itemCount: accounts.length + 1, // +1 for "None"
      itemBuilder: (context, index) {
        if (index == 0) {
          return SelectSheetItem(
            name: 'No Linked Account',
            accentColor: AppTheme.textLightColor(context),
            iconCodePoint: Icons.link_off_rounded.codePoint,
            selected: selectedId == null,
            onTap: () => Navigator.pop(context, ''),
          );
        }
        return Consumer(
          builder: (context, ref, _) {
            final liveAccounts = ref.watch(accountProvider).value ?? [];
            final acc = liveAccounts.firstWhere(
              (a) => a.id == accounts[index - 1].id,
              orElse: () => accounts[index - 1],
            );
            final balance = stats.accountBalances[acc.id] ?? 0.0;
            return AccountItem(
              account: acc,
              balance: balance,
              currencySymbol: currency.symbol,
              isSelected: acc.id == selectedId,
              onTap: () => Navigator.pop(context, acc.id),
            );
          },
        );
      },
    );
    if (id != null) {
      if (mounted) {
        onSelected(id.isEmpty ? null : id);
      }
    }
  }
}
