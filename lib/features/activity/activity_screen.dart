import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:koin/features/analysis/analysis_screen.dart';
import 'package:koin/features/reports/custom_reports_screen.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:koin/core/widgets/koin_segmented_control.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticService.selection();
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIMELINE',
                      style: TextStyle(
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ).animate().fade(duration: 400.ms).slideY(begin: -0.2),
                    const SizedBox(height: 4),
                    Text(
                          'Activity & Flow',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.textColor(context),
                          ),
                        )
                        .animate()
                        .fade(duration: 400.ms, delay: 100.ms)
                        .slideY(begin: -0.2),
                  ],
                ),
              ),
              GestureDetector(
                    onTap: () {
                      HapticService.light();
                      Navigator.push(
                        context,
                        SlideUpRoute(page: const CustomReportsScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.summarize_outlined,
                        color: AppTheme.textColor(context),
                        size: 22,
                      ),
                    ),
                  )
                  .animate()
                  .fade(duration: 400.ms, delay: 200.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
          const SizedBox(height: 20),
          KoinSegmentedControl(
                controller: _tabController,
                leftLabel: 'Analysis',
                rightLabel: 'Transactions',
              )
              .animate()
              .fade(delay: 100.ms)
              .scale(begin: const Offset(0.95, 0.95)),
        ],
      ),
    );
  }
}
