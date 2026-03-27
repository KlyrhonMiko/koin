import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/currency.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Branding
            GestureDetector(
              onTap: () => HapticService.light(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient(context),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 32),
                    ),
                    const Gap(12),
                    const Text(
                      'Koin',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const Gap(4),
                    Text(
                      'Personal Finance Tracker',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(32),
            _buildSectionHeader(context, 'Appearance'),
            const Gap(12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.dividerColor(context)),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppTheme.primaryColor(context),
                        size: 20,
                      ),
                    ),
                    title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    trailing: Switch.adaptive(
                      value: settings.isDarkMode,
                      activeTrackColor: AppTheme.primaryColor(context),
                      onChanged: (val) {
                        HapticService.medium();
                        ref.read(settingsProvider.notifier).toggleDarkMode();
                      },
                    ),
                  ),
                  Divider(height: 1, indent: 60, color: AppTheme.dividerColor(context)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Theme Color', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        const Gap(16),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            itemCount: AppTheme.accentColors.length,
                            separatorBuilder: (context, index) => const Gap(12),
                            itemBuilder: (context, index) {
                              final color = AppTheme.accentColors[index];
                              final isSelected = settings.themeColor.toARGB32() == color.toARGB32();
                              return GestureDetector(
                                onTap: () {
                                  HapticService.light();
                                  ref.read(settingsProvider.notifier).setThemeColor(color);
                                },
                                child: Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppTheme.textColor(context) : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(28),
            _buildSectionHeader(context, 'Preferences'),
            const Gap(12),
            _buildSettingCard(
              context,
              title: 'Currency',
              subtitle: '${settings.currency.name} (${settings.currency.symbol})',
              icon: Icons.payments_outlined,
              onTap: () => _showCurrencyPicker(context, ref, settings.currency),
            ),

            const Gap(28),
            _buildSectionHeader(context, 'About'),
            const Gap(12),
            _buildSettingCard(
              context,
              title: 'Version',
              subtitle: '1.0.0 (Premium Build)',
              icon: Icons.info_outline_rounded,
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textLightColor(context),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: ListTile(
        onTap: () {
          HapticService.light();
          onTap?.call();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor(context), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.textLightColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: onTap != null
            ? Icon(Icons.chevron_right_rounded, color: AppTheme.textLightColor(context), size: 20)
            : null,
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, Currency currentCurrency) {
    HapticService.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const Gap(12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(20),
            const Text(
              'Select Currency',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Gap(20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: Currency.supportedCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = Currency.supportedCurrencies[index];
                  final isSelected = currency.code == currentCurrency.code;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor(context).withValues(alpha: 0.08) : AppTheme.surfaceLightColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected ? Border.all(color: AppTheme.primaryColor(context), width: 1.5) : Border.all(color: AppTheme.dividerColor(context)),
                    ),
                    child: ListTile(
                      onTap: () {
                        HapticService.light();
                        ref.read(settingsProvider.notifier).setCurrency(currency);
                        Navigator.pop(context);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor(context) : AppTheme.dividerColor(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currency.symbol,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        currency.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppTheme.primaryColor(context) : AppTheme.textColor(context),
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        currency.code,
                        style: TextStyle(fontSize: 12, color: AppTheme.textLightColor(context)),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor(context), size: 22)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
