import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/providers/navigation_provider.dart';

class ActivityAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final int activeIndex; // 0 for Transactions, 1 for Analysis

  const ActivityAppBar({
    super.key,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.textLightColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (activeIndex != 0) {
                        ref.read(pageControllerProvider).animateToPage(
                          1, // Transactions is index 1
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        color: activeIndex == 0 ? AppTheme.primaryColor(context) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: activeIndex == 0 ? [
                          BoxShadow(
                            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Transactions',
                        style: TextStyle(
                          color: activeIndex == 0 ? Colors.white : AppTheme.textLightColor(context),
                          fontWeight: activeIndex == 0 ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (activeIndex != 1) {
                        ref.read(pageControllerProvider).animateToPage(
                          2, // Analysis is index 2
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        color: activeIndex == 1 ? AppTheme.primaryColor(context) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: activeIndex == 1 ? [
                          BoxShadow(
                            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Analysis',
                        style: TextStyle(
                          color: activeIndex == 1 ? Colors.white : AppTheme.textLightColor(context),
                          fontWeight: activeIndex == 1 ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 56);
}
