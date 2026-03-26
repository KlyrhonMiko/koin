import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/providers/navigation_provider.dart';

class OverlayActivityAppBar extends ConsumerWidget {
  const OverlayActivityAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = ref.watch(pageControllerProvider);

    return AnimatedBuilder(
      animation: pageController,
      builder: (context, child) {
        if (!pageController.hasClients) return const SizedBox.shrink();
        final page = pageController.page ?? 3.0;

        if (page <= 0.0 || page >= 4.0) return const SizedBox.shrink();

        final screenWidth = MediaQuery.of(context).size.width;
        double offsetX = 0.0;
        
        if (page < 1.0) {
          offsetX = (1.0 - page) * screenWidth;
        } else if (page > 2.0 && page < 3.0) {
          offsetX = (2.0 - page) * screenWidth;
        } else if (page >= 3.0) {
          offsetX = -screenWidth;
        }

        final progress = (page - 1.0).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: _buildBar(context, progress, ref),
        );
      },
    );
  }

  Widget _buildBar(BuildContext context, double progress, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Container(
      width: double.infinity,
      height: topPadding + kToolbarHeight + 56,
      padding: EdgeInsets.only(top: topPadding),
      color: AppTheme.surfaceColor(context), // We add solid background to perfectly hide the screens sliding underneath if there is any overlap
      child: Column(
        children: [
          SizedBox(
            height: kToolbarHeight,
            child: Stack(
              children: [
                const Center(
                  child: Text(
                    'Activity', 
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.textLightColor(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Positioned(
                    left: progress * ((MediaQuery.of(context).size.width - 40) / 2),
                    top: 0,
                    bottom: 0,
                    width: (MediaQuery.of(context).size.width - 40) / 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor(context),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if ((ref.read(pageControllerProvider).page ?? 1) > 1.0) {
                              ref.read(pageControllerProvider).animateToPage(
                                1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              'Transactions',
                              style: TextStyle(
                                color: progress < 0.5 ? Colors.white : AppTheme.textLightColor(context),
                                fontWeight: progress < 0.5 ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if ((ref.read(pageControllerProvider).page ?? 2) < 2.0) {
                              ref.read(pageControllerProvider).animateToPage(
                                2,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              'Analysis',
                              style: TextStyle(
                                color: progress >= 0.5 ? Colors.white : AppTheme.textLightColor(context),
                                fontWeight: progress >= 0.5 ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
