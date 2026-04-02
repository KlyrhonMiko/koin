import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:koin/core/database_helper.dart';
import 'dart:io';
import 'package:koin/core/models/currency.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(16),
              // Inline header
              Row(
                children: [
                  PressableScale(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.dividerColor(context),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ),
                  const Gap(16),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
              const Gap(24),

              // App Branding Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient(context),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Gap(12),
                    const Text(
                      'Koin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      'Personal Finance Tracker',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'v1.1.0',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(32),

              // ── Appearance ──
              _buildSectionHeader(context, 'Appearance'),
              const Gap(12),
              _buildGroupedCard(
                context,
                children: [
                  // Theme Mode selector
                  ListTile(
                    onTap: () {
                      HapticService.light();
                      _showThemeModePicker(context, ref, settings.themeMode);
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    leading: _buildIconBox(
                      context,
                      settings.themeMode == ThemeMode.system
                          ? Icons.brightness_auto_rounded
                          : settings.themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                    ),
                    title: const Text(
                      'Theme Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      settings.themeMode == ThemeMode.system
                          ? 'Follow System'
                          : settings.themeMode == ThemeMode.dark
                          ? 'Dark Mode'
                          : 'Light Mode',
                      style: TextStyle(
                        color: AppTheme.textLightColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textLightColor(context),
                      size: 20,
                    ),
                  ),
                  _buildInlineDivider(context),
                  // Theme Color picker
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Theme Color',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                        ),
                        const Gap(2),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            itemCount: AppTheme.accentColors.length,
                            separatorBuilder: (context, index) => const Gap(10),
                            itemBuilder: (context, index) {
                              final color = AppTheme.accentColors[index];
                              final isSelected =
                                  settings.themeColor.toARGB32() ==
                                  color.toARGB32();
                              return PressableScale(
                                onTap: () {
                                  HapticService.light();
                                  ref
                                      .read(settingsProvider.notifier)
                                      .setThemeColor(color);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: AppTheme.surfaceColor(
                                              context,
                                            ),
                                            width: 3,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: color,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        )
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
              const Gap(28),

              // ── Preferences ──
              _buildSectionHeader(context, 'Preferences'),
              const Gap(12),
              _buildGroupedCard(
                context,
                children: [
                  _buildSettingTile(
                    context,
                    title: 'Currency',
                    subtitle:
                        '${settings.currency.name} (${settings.currency.symbol})',
                    icon: Icons.payments_outlined,
                    onTap: () =>
                        _showCurrencyPicker(context, ref, settings.currency),
                  ),
                ],
              ),
              const Gap(28),

              // ── Data Management ──
              _buildSectionHeader(context, 'Data Management'),
              const Gap(12),
              _buildGroupedCard(
                context,
                children: [
                  _buildSettingTile(
                    context,
                    title: 'Backup Data',
                    subtitle: 'Export your data to a safe place',
                    icon: Icons.upload_file_rounded,
                    onTap: () => _handleBackup(context, ref),
                  ),
                  _buildInlineDivider(context),
                  _buildSettingTile(
                    context,
                    title: 'Restore Data',
                    subtitle: 'Import data from a backup file',
                    icon: Icons.download_rounded,
                    onTap: () => _handleRestore(context, ref),
                  ),
                ],
              ),
              const Gap(28),

              // ── Danger Zone ──
              _buildSectionHeader(context, 'Danger Zone'),
              const Gap(12),
              _buildGroupedCard(
                context,
                children: [
                  _buildSettingTile(
                    context,
                    title: 'Delete All Records',
                    subtitle: 'Clear all your transaction history',
                    icon: Icons.delete_sweep_rounded,
                    isDestructive: true,
                    onTap: () => _handleDeleteAllTransactions(context, ref),
                  ),
                  _buildInlineDivider(context),
                  _buildSettingTile(
                    context,
                    title: 'Delete All Data',
                    subtitle: 'Clear all transactions, savings, and goals',
                    icon: Icons.delete_forever_rounded,
                    isDestructive: true,
                    onTap: () => _handleDeleteAllData(context, ref),
                  ),
                  _buildInlineDivider(context),
                  _buildSettingTile(
                    context,
                    title: 'Factory Reset',
                    subtitle: 'Reset app to its initial state',
                    icon: Icons.restore_rounded,
                    isDestructive: true,
                    onTap: () => _handleFactoryReset(context, ref),
                  ),
                ],
              ),
              const Gap(28),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ──

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textLightColor(context),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInlineDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 64,
      color: AppTheme.dividerColor(context),
    );
  }

  Widget _buildIconBox(
    BuildContext context,
    IconData icon, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : AppTheme.primaryColor(context);
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: () {
        HapticService.light();
        onTap?.call();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: _buildIconBox(context, icon, isDestructive: isDestructive),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDestructive ? Colors.red : null,
        ),
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
          ? Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textLightColor(context),
              size: 20,
            )
          : null,
    );
  }

  Future<void> _handleBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmationBottomSheet(
      context,
      title: 'Backup Data',
      message:
          'Are you sure you want to backup your database? This will save the backup file directly to your device.',
      confirmText: 'Backup',
      icon: Icons.upload_file_rounded,
    );

    if (confirmed != true) return;

    try {
      // Save current SharedPreferences to Database
      final prefs = ref.read(sharedPreferencesProvider);
      final settings = {
        if (prefs.getString('currency_code') != null)
          'currency_code': prefs.getString('currency_code')!,
        if (prefs.getInt('theme_color') != null)
          'theme_color': prefs.getInt('theme_color')!.toString(),
        if (prefs.getBool('is_dark_mode') != null)
          'is_dark_mode': prefs.getBool('is_dark_mode')!.toString(),
      };
      await DatabaseHelper.instance.saveSettingsToDb(settings);

      final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
      final file = File(dbPath);
      if (await file.exists()) {
        final dateStr = DateFormat('yyyy_MM_dd').format(DateTime.now());
        final fileName = 'koin_backup_$dateStr';

        // Read DB file bytes
        final bytes = await file.readAsBytes();

        // Prompt user for save location
        final savedPath = await FileSaver.instance.saveAs(
          name: fileName,
          bytes: bytes,
          fileExtension: 'db',
          mimeType: MimeType.other,
        );

        if (context.mounted && savedPath != null && savedPath.isNotEmpty) {
          KoinSnackBar.success(context, 'Backup saved successfully');
        }
      } else {
        if (context.mounted) {
          KoinSnackBar.error(context, 'Database file not found!');
        }
      }
    } catch (e) {
      if (context.mounted) {
        KoinSnackBar.error(context, 'Error creating backup: $e');
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmationBottomSheet(
      context,
      title: 'Restore Data',
      message:
          'Restoring data will replace all your current app data. Are you sure you want to continue?',
      confirmText: 'Restore',
      icon: Icons.download_rounded,
      isDestructive: true,
    );

    if (confirmed != true) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final success = await DatabaseHelper.instance.restoreDatabase(path);

        if (success) {
          // Restore settings from db to SharedPreferences
          final settingsFromDb = await DatabaseHelper.instance
              .loadSettingsFromDb();
          final prefs = ref.read(sharedPreferencesProvider);
          if (settingsFromDb.containsKey('currency_code')) {
            await prefs.setString(
              'currency_code',
              settingsFromDb['currency_code']!,
            );
          }
          if (settingsFromDb.containsKey('theme_color') &&
              settingsFromDb['theme_color']!.isNotEmpty) {
            await prefs.setInt(
              'theme_color',
              int.parse(settingsFromDb['theme_color']!),
            );
          }
          if (settingsFromDb.containsKey('is_dark_mode')) {
            await prefs.setBool(
              'is_dark_mode',
              settingsFromDb['is_dark_mode'] == 'true',
            );
          }

          if (!context.mounted) return;

          ref.invalidate(settingsProvider);
          ref.invalidate(transactionProvider);
          ref.invalidate(accountProvider);
          ref.invalidate(categoriesProvider);
          ref.invalidate(savingsGoalsProvider);
          KoinSnackBar.success(context, 'Data restored successfully!');
        } else {
          if (!context.mounted) return;
          KoinSnackBar.error(context, 'Failed to restore data.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        KoinSnackBar.error(context, 'Error restoring data: $e');
      }
    }
  }

  Future<void> _handleDeleteAllTransactions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await _showConfirmationBottomSheet(
      context,
      title: 'Delete All Records',
      message:
          'Are you sure you want to delete all your transaction records? This action cannot be undone.',
      confirmText: 'Delete',
      icon: Icons.delete_sweep_rounded,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      await DatabaseHelper.instance.deleteAllTransactions();
      ref.invalidate(transactionProvider);
      ref.invalidate(accountProvider);

      if (context.mounted) {
        KoinSnackBar.success(context, 'All transactions deleted.');
      }
    }
  }

  Future<void> _handleDeleteAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmationBottomSheet(
      context,
      title: 'Delete All Data',
      message:
          'This will delete all transactions, savings logs, accounts, and categories. Are you sure?',
      confirmText: 'Delete Data',
      icon: Icons.delete_forever_rounded,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      await DatabaseHelper.instance.deleteAllData();
      ref.invalidate(transactionProvider);
      ref.invalidate(accountProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(savingsGoalsProvider);

      if (context.mounted) {
        KoinSnackBar.success(context, 'All data deleted.');
      }
    }
  }

  Future<void> _handleFactoryReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmationBottomSheet(
      context,
      title: 'Factory Reset',
      message:
          'This will completely wipe out your database and settings, restoring the app directly back to its initial state. Are you absolutely certain?',
      confirmText: 'Factory Reset',
      icon: Icons.restore_rounded,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      await DatabaseHelper.instance.resetDatabase();
      await ref.read(settingsProvider.notifier).resetSettings();
      ref.invalidate(transactionProvider);
      ref.invalidate(accountProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(savingsGoalsProvider);

      if (context.mounted) {
        KoinSnackBar.success(
          context,
          'App has been reset to factory defaults.',
        );
      }
    }
  }

  Future<bool?> _showConfirmationBottomSheet(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required IconData icon,
    bool isDestructive = false,
  }) {
    HapticService.light();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(24),
            Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        (isDestructive
                                ? Colors.red
                                : AppTheme.primaryColor(context))
                            .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive
                        ? Colors.red
                        : AppTheme.primaryColor(context),
                    size: 32,
                  ),
                )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 400.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: 300.ms),
            const Gap(20),
            Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                )
                .animate()
                .fadeIn(delay: 100.ms, duration: 300.ms)
                .slideY(
                  begin: 0.15,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
            const Gap(12),
            Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textLightColor(context),
                    height: 1.5,
                  ),
                )
                .animate()
                .fadeIn(delay: 180.ms, duration: 300.ms)
                .slideY(
                  begin: 0.15,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
            const Gap(32),
            Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.textLightColor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDestructive
                              ? Colors.red
                              : AppTheme.primaryColor(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          confirmText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                .animate()
                .fadeIn(delay: 260.ms, duration: 300.ms)
                .slideY(
                  begin: 0.2,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
            const Gap(8),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    Currency currentCurrency,
  ) {
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
                      color: isSelected
                          ? AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.08)
                          : AppTheme.surfaceLightColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.primaryColor(context),
                              width: 1.5,
                            )
                          : Border.all(color: AppTheme.dividerColor(context)),
                    ),
                    child: ListTile(
                      onTap: () {
                        HapticService.light();
                        ref
                            .read(settingsProvider.notifier)
                            .setCurrency(currency);
                        Navigator.pop(context);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor(context)
                              : AppTheme.dividerColor(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currency.symbol,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        currency.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? AppTheme.primaryColor(context)
                              : AppTheme.textColor(context),
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        currency.code,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLightColor(context),
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryColor(context),
                              size: 22,
                            )
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

  void _showThemeModePicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    HapticService.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'Select Theme Mode',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Gap(20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildThemeOption(
                    context,
                    ref,
                    title: 'Follow System',
                    subtitle: 'Match your device\'s theme settings',
                    icon: Icons.brightness_auto_rounded,
                    mode: ThemeMode.system,
                    isSelected: currentMode == ThemeMode.system,
                  ),
                  const Gap(8),
                  _buildThemeOption(
                    context,
                    ref,
                    title: 'Light Mode',
                    subtitle: 'Always use a light appearance',
                    icon: Icons.light_mode_rounded,
                    mode: ThemeMode.light,
                    isSelected: currentMode == ThemeMode.light,
                  ),
                  const Gap(8),
                  _buildThemeOption(
                    context,
                    ref,
                    title: 'Dark Mode',
                    subtitle: 'Always use a dark appearance',
                    icon: Icons.dark_mode_rounded,
                    mode: ThemeMode.dark,
                    isSelected: currentMode == ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor(context).withValues(alpha: 0.08)
            : AppTheme.surfaceLightColor(context),
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: AppTheme.primaryColor(context), width: 1.5)
            : Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: ListTile(
        onTap: () {
          HapticService.light();
          ref.read(settingsProvider.notifier).setThemeMode(mode);
          Navigator.pop(context);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor(context)
                : AppTheme.dividerColor(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : AppTheme.textColor(context),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? AppTheme.primaryColor(context)
                : AppTheme.textColor(context),
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textLightColor(context),
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor(context),
                size: 22,
              )
            : null,
      ),
    );
  }
}
