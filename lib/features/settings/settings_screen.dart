import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:file_saver/file_saver.dart';
import 'package:koin/core/core.dart';

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
                  const KoinBackButton(),
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
                        'v1.1.1',
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
              const FormSectionTitle.subhead(
                title: 'Appearance',
                padding: EdgeInsets.only(left: 4),
              ),
              const Gap(12),
              KoinGroupedCard(
                children: [
                  // Theme Mode selector
                  KoinSettingTile(
                    onTap: () =>
                        _showThemeModePicker(context, ref, settings.themeMode),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    icon: settings.themeMode == ThemeMode.system
                        ? Icons.brightness_auto_rounded
                        : settings.themeMode == ThemeMode.dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    title: 'Theme Mode',
                    subtitle: settings.themeMode == ThemeMode.system
                        ? 'Follow System'
                        : settings.themeMode == ThemeMode.dark
                        ? 'Dark Mode'
                        : 'Light Mode',
                  ),
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
              const FormSectionTitle.subhead(
                title: 'Preferences',
                padding: EdgeInsets.only(left: 4),
              ),
              const Gap(12),
              KoinGroupedCard(
                children: [
                  KoinSettingTile(
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
              const FormSectionTitle.subhead(
                title: 'Data Management',
                padding: EdgeInsets.only(left: 4),
              ),
              const Gap(12),
              KoinGroupedCard(
                children: [
                  KoinSettingTile(
                    title: 'Backup Data',
                    subtitle: 'Export your data to a safe place',
                    icon: Icons.upload_file_rounded,
                    onTap: () => _handleBackup(context, ref),
                  ),
                  KoinSettingTile(
                    title: 'Restore Data',
                    subtitle: 'Import data from a backup file',
                    icon: Icons.download_rounded,
                    onTap: () => _handleRestore(context, ref),
                  ),
                ],
              ),
              const Gap(28),

              // ── Danger Zone ──
              const FormSectionTitle.subhead(
                title: 'Danger Zone',
                padding: EdgeInsets.only(left: 4),
              ),
              const Gap(12),
              KoinGroupedCard(
                children: [
                  KoinSettingTile(
                    title: 'Delete All Records',
                    subtitle: 'Clear all your transaction history',
                    icon: Icons.delete_sweep_rounded,
                    isDestructive: true,
                    onTap: () => _handleDeleteAllTransactions(context, ref),
                  ),
                  KoinSettingTile(
                    title: 'Delete All Data',
                    subtitle: 'Clear all records, accounts, and categories',
                    icon: Icons.delete_forever_rounded,
                    isDestructive: true,
                    onTap: () => _handleDeleteAllData(context, ref),
                  ),
                  KoinSettingTile(
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
      final maintenance = ref.read(appMaintenanceProvider);
      final bundle = await maintenance.createBackup();

      if (bundle != null) {
        // Prompt user for save location
        final savedPath = await FileSaver.instance.saveAs(
          name: bundle.fileName,
          bytes: bundle.bytes,
          fileExtension: 'db',
          mimeType: MimeType.other,
        );

        if (context.mounted && savedPath != null && savedPath.isNotEmpty) {
          KoinSnackBar.success(
            context,
            'Backup saved successfully',
            subtitle: 'Your database is now safe',
          );
        }
      } else {
        if (context.mounted) {
          KoinSnackBar.error(
            context,
            'Database file not found!',
            subtitle: 'Please try again or contact support',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        KoinSnackBar.error(
          context,
          'Error creating backup',
          subtitle: 'An unexpected error occurred: $e',
        );
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
      final file = await FilePicker.pickFile();
      if (file != null) {
        String? path = file.path;
        File? tempFile;
        try {
          if (path == null) {
            final bytes = await file.readAsBytes();
            final tempDir = await getTemporaryDirectory();
            tempFile = File(p.join(tempDir.path, file.name));
            await tempFile.writeAsBytes(bytes);
            path = tempFile.path;
          }

          final maintenance = ref.read(appMaintenanceProvider);
          final success = await maintenance.restoreBackup(path);

          if (!context.mounted) return;

          if (success) {
            KoinSnackBar.success(
              context,
              'Data restored successfully!',
              subtitle: 'App will now refresh with your data',
            );
          } else {
            KoinSnackBar.error(
              context,
              'Failed to restore data.',
              subtitle: 'The backup file might be corrupted',
            );
          }
        } finally {
          if (tempFile != null && await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        KoinSnackBar.error(
          context,
          'Error restoring data',
          subtitle: 'Check the backup file and try again: $e',
        );
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
      await ref.read(appMaintenanceProvider).clearTransactions();

      if (context.mounted) {
        KoinSnackBar.success(
          context,
          'All transactions deleted',
          subtitle: 'Your transaction history has been cleared',
        );
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
      await ref.read(appMaintenanceProvider).clearAllData();

      if (context.mounted) {
        KoinSnackBar.success(
          context,
          'All data deleted',
          subtitle: 'All records, accounts and goals are gone',
        );
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
      await ref.read(appMaintenanceProvider).factoryReset();

      if (context.mounted) {
        KoinSnackBar.success(
          context,
          'App Factory Reset',
          subtitle: 'Starting fresh with a clean slate',
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
          children:
              [
                    const KoinBottomSheetHandle(
                      padding: EdgeInsets.only(bottom: 24),
                    ),
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
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textLightColor(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
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
            const KoinBottomSheetHandle(
              padding: EdgeInsets.only(top: 12, bottom: 20),
            ),
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
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.primaryColor(context),
                              width: 1.5,
                            )
                          : Border.all(color: AppTheme.dividerColor(context)),
                    ),
                    child: Material(
                      color: isSelected
                          ? AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.08)
                          : AppTheme.surfaceLightColor(context),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
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
        padding: const EdgeInsets.only(
          bottom: 32,
          left: 24,
          right: 24,
          top: 12,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KoinBottomSheetHandle(padding: EdgeInsets.only(bottom: 24)),
            Text(
              'App Appearance',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.5,
              ),
            ),
            const Gap(8),
            Text(
              'Choose how Koin looks to you',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textLightColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(32),
            Row(
              children:
                  [
                        Expanded(
                          child: _buildThemeOption(
                            context,
                            ref,
                            title: 'System',
                            icon: Icons.brightness_auto_rounded,
                            mode: ThemeMode.system,
                            isSelected: currentMode == ThemeMode.system,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildThemeOption(
                            context,
                            ref,
                            title: 'Light',
                            icon: Icons.light_mode_rounded,
                            mode: ThemeMode.light,
                            isSelected: currentMode == ThemeMode.light,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildThemeOption(
                            context,
                            ref,
                            title: 'Dark',
                            icon: Icons.dark_mode_rounded,
                            mode: ThemeMode.dark,
                            isSelected: currentMode == ThemeMode.dark,
                          ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
  }) {
    final primaryColor = AppTheme.primaryColor(context);
    final surfaceColor = AppTheme.surfaceLightColor(context);

    return GestureDetector(
      onTap: () {
        HapticService.light();
        ref.read(settingsProvider.notifier).setThemeMode(mode);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? primaryColor : AppTheme.dividerColor(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : surfaceColor,
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(
                        color: AppTheme.dividerColor(
                          context,
                        ).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : AppTheme.textLightColor(context),
                size: 28,
              ),
            ),
            const Gap(16),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? primaryColor : AppTheme.textColor(context),
                fontSize: 14,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
