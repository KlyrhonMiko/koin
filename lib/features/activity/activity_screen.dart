import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:koin/features/analysis/analysis_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: AppTheme.primaryColor(context),
            labelColor: AppTheme.primaryColor(context),
            unselectedLabelColor: AppTheme.textLightColor(context),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            tabs: const [
              Tab(text: 'Transactions'),
              Tab(text: 'Analysis'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TransactionsListScreen(),
            AnalysisScreen(),
          ],
        ),
      ),
    );
  }
}
