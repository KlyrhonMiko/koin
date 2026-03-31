import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:koin/features/analysis/analysis_screen.dart';

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
          Text(
            'TIMELINE',
            style: TextStyle(
              color: AppTheme.textLightColor(context).withValues(alpha: 0.7),
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
          ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: -0.2),
          const SizedBox(height: 20),
          _buildSegmentedControl(context)
              .animate()
              .fade(delay: 100.ms)
              .scale(begin: const Offset(0.95, 0.95)),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / 2;
                  final animationValue = _tabController.animation!.value;

                  return Stack(
                    children: [
                      // Real-time tracking Indicator
                      Positioned(
                        top: 4,
                        bottom: 4,
                        left: 4 + (tabWidth - 4) * animationValue,
                        width: tabWidth - 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor(context),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 3,
                              width: 32,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor(
                                      context,
                                    ).withValues(alpha: 0.6),
                                    AppTheme.primaryColor(context),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticService.selection();
                                _tabController.animateTo(0);
                              },
                              child: Center(
                                child: Text(
                                  'Analysis',
                                  style: TextStyle(
                                    fontWeight: _tabController.index == 0
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: _tabController.index == 0
                                        ? AppTheme.primaryColor(context)
                                        : AppTheme.textLightColor(context),
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticService.selection();
                                _tabController.animateTo(1);
                              },
                              child: Center(
                                child: Text(
                                  'Transactions',
                                  style: TextStyle(
                                    fontWeight: _tabController.index == 1
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: _tabController.index == 1
                                        ? AppTheme.primaryColor(context)
                                        : AppTheme.textLightColor(context),
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
