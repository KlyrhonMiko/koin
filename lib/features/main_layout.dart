import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/features/accounts/accounts_screen.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
import 'package:koin/features/savings/savings_list_screen.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:koin/core/providers/navigation_provider.dart';

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
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: AppTheme.surfaceColor(context),
        systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: PageView(
          controller: pageController,
          onPageChanged: onPageChanged,
          children: const [
            DashboardScreen(),
            TransactionsListScreen(),
            AccountsScreen(),
            SavingsListScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            border: Border(
              top: BorderSide(
                color: AppTheme.dividerColor(context),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    index: 0,
                    currentIndex: currentIndex,
                    onTap: onItemTapped,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    label: 'Transactions',
                    index: 1,
                    currentIndex: currentIndex,
                    onTap: onItemTapped,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    label: 'Accounts',
                    index: 2,
                    currentIndex: currentIndex,
                    onTap: onItemTapped,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.savings_outlined,
                    activeIcon: Icons.savings_rounded,
                    label: 'Savings',
                    index: 3,
                    currentIndex: currentIndex,
                    onTap: onItemTapped,
                  ),
                ],
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
    required int index,
    required int currentIndex,
    required Function(int) onTap,
  }) {
    final isActive = index == currentIndex;
    final primaryColor = AppTheme.primaryColor(context);
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? primaryColor : AppTheme.textLightColor(context).withValues(alpha: 0.6),
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
