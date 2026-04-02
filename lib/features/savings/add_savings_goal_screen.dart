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
import 'package:uuid/uuid.dart';
import 'package:koin/core/widgets/koin_back_button.dart';

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
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
              onPrimary: Colors.black,
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
        }
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final goal = SavingsGoal(
        id: widget.goal?.id ?? const Uuid().v4(),
        name: _nameController.text,
        targetAmount: double.parse(_amountController.text),
        currentAmount: widget.goal?.currentAmount ?? 0.0,
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text,
      );

      if (widget.goal == null) {
        ref.read(savingsGoalsProvider.notifier).addGoal(goal);
      } else {
        ref.read(savingsGoalsProvider.notifier).updateGoal(goal);
      }

      HapticService.success();
      Navigator.pop(context);
    } else {
      HapticService.error();
    }
  }

  int get _totalDays => _endDate.difference(_startDate).inDays;

  String _getDailyEstimate() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || _totalDays <= 0) return '—';
    final settings = ref.read(settingsProvider);
    final fmt = NumberFormat.simpleCurrency(name: settings.currency.code);
    return fmt.format(amount / _totalDays);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.goal != null;
    final settings = ref.watch(settingsProvider);
    final primaryColor = AppTheme.primaryColor(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const KoinBackButton(),
                  const Gap(16),
                  Text(
                    isEditing ? 'Edit Goal' : 'New Savings Goal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Goal Details
                      _buildSection(
                        context,
                        title: 'Goal Details',
                        delay: 0,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Goal Name',
                              hintText: 'e.g. New Car, Vacation Fund',
                              prefixIcon: Icon(Icons.flag_rounded),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please enter a name'
                                : null,
                          ),
                          const Gap(14),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              labelText: 'Target Amount',
                              hintText: 'How much do you want to save?',
                              prefixIcon: const Icon(Icons.payments_outlined),
                              prefixText: '${settings.currency.symbol} ',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Please enter an amount';
                              if (double.tryParse(value) == null)
                                return 'Please enter a valid number';
                              return null;
                            },
                          ),
                        ],
                      ),
                      const Gap(14),

                      // Section 2: Timeline
                      _buildSection(
                        context,
                        title: 'Timeline',
                        delay: 80,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateSelector(
                                  context,
                                  label: 'Start',
                                  date: _startDate,
                                  icon: Icons.play_arrow_rounded,
                                  onTap: () {
                                    HapticService.light();
                                    _selectDate(context, true);
                                  },
                                ),
                              ),
                              const Gap(12),
                              // Connector arrow
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppTheme.textLightColor(
                                    context,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: _buildDateSelector(
                                  context,
                                  label: 'End',
                                  date: _endDate,
                                  icon: Icons.flag_rounded,
                                  onTap: () {
                                    HapticService.light();
                                    _selectDate(context, false);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const Gap(14),
                          // Duration + estimate pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLightColor(context),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 15,
                                  color: primaryColor.withValues(alpha: 0.6),
                                ),
                                const Gap(8),
                                Text(
                                  '$_totalDays days',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textColor(context),
                                  ),
                                ),
                                const Gap(8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppTheme.textLightColor(
                                      context,
                                    ).withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Gap(8),
                                Expanded(
                                  child: Text(
                                    '${_getDailyEstimate()}/day to reach goal',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textLightColor(
                                        context,
                                      ).withValues(alpha: 0.6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(14),

                      // Section 3: Notes
                      _buildSection(
                        context,
                        title: 'Notes',
                        subtitle: 'Optional',
                        delay: 160,
                        children: [
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              hintText: 'Add any notes about this goal...',
                              prefixIcon: Icon(Icons.edit_note_rounded),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const Gap(32),

                      // Save button
                      Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: AppTheme.primaryGradient(context),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  spreadRadius: -2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                              child: Text(
                                isEditing ? 'Update Goal' : 'Create Goal',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fade(delay: 240.ms, duration: 400.ms)
                          .slideY(begin: 0.06, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLightColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.5),
                ),
                const Gap(6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.5),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Gap(6),
            Text(
              DateFormat.yMMMd().format(date),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required int delay,
    required List<Widget> children,
  }) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header — clean text only, no icon container
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLightColor(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Gap(18),
              ...children,
            ],
          ),
        )
        .animate()
        .fade(delay: delay.ms, duration: 400.ms)
        .slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }
}
