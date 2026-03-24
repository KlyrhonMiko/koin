import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal == null ? 'New Savings Goal' : 'Edit Goal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Goal Name',
                  prefixIcon: Icon(Icons.star_rounded),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
              ),
              const Gap(16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Target Amount',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter an amount';
                  if (double.tryParse(value) == null) return 'Please enter a valid number';
                  return null;
                },
              ),
              const Gap(16),
              // Start date
              GestureDetector(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(_startDate),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Gap(16),
              // End date
              GestureDetector(
                onTap: () => _selectDate(context, false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'End Date',
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(_endDate),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Gap(16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 3,
              ),
              const Gap(32),
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
                    widget.goal == null ? 'Create Goal' : 'Update Goal',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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
