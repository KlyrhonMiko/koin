import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/transactions/transactions.dart';
import 'package:koin/features/analysis/analysis_screen.dart';
import 'package:koin/features/reports/reports.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(activityTabProvider);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: (initialTab >= 0 && initialTab < 2) ? initialTab : 0,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticService.selection();
      } else {
        ref.read(activityTabProvider.notifier).setIndex(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activityTabProvider, (previous, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: const [AnalysisScreen(), TransactionsListScreen()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KoinScreenHeader(
            tag: 'TIMELINE',
            title: 'Activity & Flow',
            padding: EdgeInsets.zero,
            trailing: IconButton(
              onPressed: () {
                HapticService.light();
                Navigator.push(
                  context,
                  SlideUpRoute(page: const CustomReportsScreen()),
                );
              },
              icon: Icon(
                Icons.summarize_outlined,
                color: AppTheme.textColor(context),
              ),
              tooltip: 'Custom Reports',
            ),
          ),
          const SizedBox(height: 20),
          KoinSegmentedControl(
            controller: _tabController,
            leftLabel: 'Analysis',
            rightLabel: 'Transactions',
          ),
        ]
        .animate(interval: 40.ms)
        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.95, 0.95),
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }
}
