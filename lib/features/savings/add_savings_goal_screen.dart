import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:uuid/uuid.dart';

class AddSavingsGoalScreen extends ConsumerStatefulWidget {
  final SavingsGoal? goal;

  const AddSavingsGoalScreen({super.key, this.goal});

  @override
  ConsumerState<AddSavingsGoalScreen> createState() => _AddSavingsGoalScreenState();
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
    _amountController = TextEditingController(text: widget.goal?.targetAmount.toString() ?? '');
    _notesController = TextEditingController(text: widget.goal?.notes ?? '');
    _startDate = widget.goal?.startDate ?? DateTime.now();
    _endDate = widget.goal?.endDate ?? DateTime.now().add(const Duration(days: 30));
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

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.goal != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Goal' : 'New Savings Goal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Goal Details
              _buildSectionCard(
                context,
                icon: Icons.star_rounded,
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
                    validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Target Amount',
                      hintText: 'How much do you want to save?',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter an amount';
                      if (double.tryParse(value) == null) return 'Please enter a valid number';
                      return null;
                    },
                  ),
                ],
              ),
              const Gap(16),

              // Section 2: Timeline
              _buildSectionCard(
                context,
                icon: Icons.calendar_month_rounded,
                title: 'Timeline',
                delay: 80,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            child: Text(
                              DateFormat.yMMMd().format(_startDate),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context, false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              prefixIcon: Icon(Icons.event_rounded),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            child: Text(
                              DateFormat.yMMMd().format(_endDate),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor(context).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.primaryColor(context).withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Text(
                          '${_endDate.difference(_startDate).inDays} days to reach your goal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor(context).withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(16),

              // Section 3: Notes
              _buildSectionCard(
                context,
                icon: Icons.notes_rounded,
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
                      color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(
                    isEditing ? 'Update Goal' : 'Create Goal',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ).animate().fade(delay: 240.ms).slideY(begin: 0.06),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
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
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppTheme.primaryColor(context)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textLightColor(context).withValues(alpha: 0.5)),
                ),
              ],
            ],
          ),
          const Gap(16),
          ...children,
        ],
      ),
    ).animate().fade(delay: delay.ms).slideY(begin: 0.06);
  }
}
