import 'package:flutter/material.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/features/cashflow/cashflow_tab.dart';

export 'package:koin/features/cashflow/cashflow_tab.dart';

/// Backward-compatible screen wrapper delegating to deep CashflowScheduleTab.
class RecurringIncomesScreen extends StatelessWidget {
  const RecurringIncomesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: CashflowScheduleTab(type: TransactionType.income),
      ),
    );
  }
}
