import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/features/accounts/accounts_screen.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
import 'package:koin/features/savings/savings_list_screen.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:koin/features/analysis/analysis_screen.dart';
import 'package:koin/features/budgets/budgets_screen.dart';
import 'package:koin/core/providers/navigation_provider.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/features/activity/overlay_activity_app_bar.dart';

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationProvider);
    final pageController = ref.watch(pageControllerProvider);
    final isDarkMode = ref.watch(settingsProvider).isDarkMode;

    void onPageChanged(int index) {
      ref.read(navigationProvider.notifier).setIndex(index);
    }

    void onItemTapped(int index) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: AppTheme.surfaceColor(context),
        systemNavigationBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        body: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Stack(
            children: [
              PageView(
                controller: pageController,
                onPageChanged: onPageChanged,
                children: const [
                  AccountsScreen(),
                  TransactionsListScreen(),
                  AnalysisScreen(),
                  DashboardScreen(),
                  BudgetsScreen(),
                  SavingsListScreen(),
                ],
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: OverlayActivityAppBar(),
              ),
            ],
          ),
        ),
        floatingActionButton: currentIndex == 3
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                ),
                label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.add_rounded),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      context,
                      icon: Icons.credit_card_outlined,
                      activeIcon: Icons.credit_card_rounded,
                      label: 'Accounts',
                      isActive: currentIndex == 0,
                      targetIndex: 0,
                      onTap: onItemTapped,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'Activity',
                      isActive: currentIndex == 1 || currentIndex == 2,
                      targetIndex: 1,
                      onTap: onItemTapped,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      label: 'Home',
                      isActive: currentIndex == 3,
                      targetIndex: 3,
                      onTap: onItemTapped,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      activeIcon: Icons.account_balance_wallet_rounded,
                      label: 'Budgets',
                      isActive: currentIndex == 4,
                      targetIndex: 4,
                      onTap: onItemTapped,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.savings_outlined,
                      activeIcon: Icons.savings_rounded,
                      label: 'Savings',
                      isActive: currentIndex == 5,
                      targetIndex: 5,
                      onTap: onItemTapped,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required int targetIndex,
    required Function(int) onTap,
  }) {
    final primaryColor = AppTheme.primaryColor(context);

    return GestureDetector(
      onTap: () => onTap(targetIndex),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? primaryColor
                  : AppTheme.textLightColor(context).withValues(alpha: 0.6),
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
