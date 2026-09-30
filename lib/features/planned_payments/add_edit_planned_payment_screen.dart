import 'package:flutter/material.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/features/cashflow/add_edit_cashflow_screen.dart';

/// Backward-compatible shallow entry point delegating to deep AddEditCashflowScreen.
class AddEditPlannedPaymentScreen extends StatelessWidget {
  final PlannedPayment? payment;

  const AddEditPlannedPaymentScreen({super.key, this.payment});

  @override
  Widget build(BuildContext context) {
    return AddEditCashflowScreen(
      payment: payment,
      initialType: TransactionType.expense,
    );
  }
}
