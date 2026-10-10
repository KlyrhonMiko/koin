import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/account_form_screen.dart';

/// Modular Accounts Tab: Encapsulates account listing, balance rendering,
/// swipe-to-delete, drag-and-drop reordering, and empty state.
class AccountsTab extends ConsumerWidget {
  final String animationSessionKey;
  final bool showEntranceAnimations;

  const AccountsTab({
    super.key,
    required this.animationSessionKey,
    required this.showEntranceAnimations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final goals = ref.watch(savingsGoalsProvider).value ?? [];

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return _buildEmptyState(context);
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(
            KoinSpacing.screenInset,
            12,
            KoinSpacing.screenInset,
            100,
          ),
          itemCount: accounts.length,
          footer: _buildAddAccountButton(context, ref),
          onReorderItem: (oldIndex, newIndex) {
            HapticService.medium();
            ref
                .read(accountProvider.notifier)
                .reorderAccounts(oldIndex, newIndex);
          },
          proxyDecorator: koinReorderProxyDecorator,
          itemBuilder: (context, index) {
            final account = accounts[index];
            final balance = stats.accountBalances[account.id] ?? 0;
            final excludedSavings = goals
                .where(
                  (g) =>
                      g.linkedAccountId == account.id &&
                      !g.includeInDashboardBalance &&
                      g.currentAmount > 0,
                )
                .fold<double>(0, (sum, g) => sum + g.currentAmount);
            final displayBalance =
                balance -
                excludedSavings.clamp(0, balance.clamp(0, double.infinity));

            Widget accountItem = AccountItem(
              account: account,
              balance: displayBalance,
              savingsAmount: goals
                  .where(
                    (g) =>
                        g.linkedAccountId == account.id &&
                        g.includeInDashboardBalance &&
                        g.currentAmount > 0,
                  )
                  .fold<double>(0, (sum, g) => sum + g.currentAmount),
              currencySymbol: currency.symbol,
              animationSessionKey: animationSessionKey,
              onTap: () {
                HapticService.light();
                Navigator.push(
                  context,
                  SlideUpRoute(page: AccountFormScreen(account: account)),
                );
              },
              onPrivateToggle: () {
                final updatedAccount = account.copyWith(
                  excludeFromTotal: !account.excludeFromTotal,
                );
                ref
                    .read(accountProvider.notifier)
                    .updateAccount(updatedAccount);
                HapticService.selection();
              },
              trailing: Listener(
                onPointerDown: (_) => HapticService.light(),
                child: ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.2),
                    size: 22,
                  ),
                ),
              ),
            );

            if (showEntranceAnimations) {
              accountItem = accountItem
                  .animate()
                  .fade(delay: (index * 60).ms, duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  );
            }

            return KeyedSubtree(
              key: ValueKey(account.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SwipeToDeleteTile(
                  key: Key('dismiss_${account.id}'),
                  borderRadius: BorderRadius.circular(24),
                  fillRoundedCorners: true,
                  backgroundColor: AppTheme.errorColor(context),
                  icon: Icons.delete_rounded,
                  confirmTitle: 'Delete Account?',
                  confirmDescription:
                      'All transactions associated with this account will be unlinked. This cannot be undone.',
                  onDelete: () {
                    HapticService.heavy();
                    ref
                        .read(accountProvider.notifier)
                        .deleteAccount(account.id);
                  },
                  child: accountItem,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildAddAccountButton(BuildContext context, WidgetRef ref) {
    final button = PressableScale(
      onTap: () {
        HapticService.medium();
        Navigator.push(context, SlideUpRoute(page: const AccountFormScreen()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: AppTheme.textLightColor(context),
              size: 20,
            ),
            const Gap(10),
            Text(
              'Add New Account',
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontWeight: KoinTypography.labelWeight,
                fontSize: KoinTypography.compact,
              ),
            ),
          ],
        ),
      ),
    );

    if (showEntranceAnimations) {
      return button
          .animate()
          .fade(duration: 250.ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.95, 0.95),
            duration: 250.ms,
            curve: Curves.easeOutCubic,
          );
    }
    return button;
  }

  Widget _buildEmptyState(BuildContext context) => KoinEmptyState.sliver(
    icon: Icons.account_balance_wallet_rounded,
    title: 'No accounts yet',
    subtitle: 'Add your first account to start tracking your money',
    action: KoinPrimaryButton(
      label: 'Add Account',
      onPressed: () {
        HapticService.medium();
        Navigator.push(context, SlideUpRoute(page: const AccountFormScreen()));
      },
    ),
  );
}
