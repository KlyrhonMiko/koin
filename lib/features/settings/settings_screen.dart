import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:koin/core/maintenance/recovery_store.dart';
import 'package:koin/core/maintenance/recovery_service.dart';

import 'backup_recovery_panel.dart';
import 'archive_manager_screen.dart';
import 'voice_language_sheet.dart';
import 'backup_password_sheet.dart';

import 'package:koin/core/maintenance/backup_encryption.dart';

import 'package:koin/core/core.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _maintenanceBusy = false;

  Future<void> _runMaintenanceAction(Future<void> Function() action) async {
    if (_maintenanceBusy) return;
    setState(() => _maintenanceBusy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(
          context,
          'Could not finish this action',
          subtitle: 'Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _maintenanceBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      KoinFormTheme(builder: (context) => _buildContent(context, ref));

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KoinSpacing.screenInset,
          ),
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
                      fontSize: KoinTypography.screenTitle,
                      fontWeight: KoinTypography.headingWeight,
                      letterSpacing: KoinTypography.headingTracking,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
              const Gap(24),

              // App Branding Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.summaryGradient(context),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      padding: const EdgeInsets.all(1),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          semanticLabel: 'Koin app icon',
                        ),
                      ),
                    ),
                    const Gap(20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Koin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: KoinTypography.summaryAmount,
                              fontWeight: KoinTypography.headingWeight,
                              letterSpacing: KoinTypography.amountTracking,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            'Personal Finance Tracker',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: KoinTypography.caption,
                              fontWeight: KoinTypography.supportingWeight,
                            ),
                          ),
                          const Gap(12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'v1.1.3',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: KoinTypography.overline,
                                fontWeight: KoinTypography.labelWeight,
                              ),
                            ),
                          ),
                        ],
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
                      horizontal: KoinSpacing.screenInset,
                      vertical: 2,
                    ),
                    icon: settings.themeMode == ThemeMode.system
                        ? KoinIcons.circleHalf
                        : settings.themeMode == ThemeMode.dark
                        ? KoinIcons.moon
                        : KoinIcons.sun,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: KoinSpacing.screenInset,
                          ),
                          child: Text(
                            'Theme Color',
                            style: TextStyle(
                              fontWeight: KoinTypography.labelWeight,
                              fontSize: KoinTypography.body,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                        ),
                        const Gap(2),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: KoinSpacing.screenInset,
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
                                semanticLabel:
                                    '${AppTheme.accentColorNames[index]} theme',
                                selected: isSelected,
                                onTap: () {
                                  HapticService.light();
                                  ref
                                      .read(settingsProvider.notifier)
                                      .setThemeColor(color);
                                },
                                child: AnimatedContainer(
                                  duration: KoinMotion.duration(
                                    context,
                                    const Duration(milliseconds: 200),
                                  ),
                                  width: 48,
                                  height: 48,
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
                                            AppTheme.boxShadow(
                                              context,
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
                                            KoinIcons.check,
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
              const Gap(KoinSpacing.sectionGap),

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
                    icon: KoinIcons.money,
                    onTap: () =>
                        _showCurrencyPicker(context, ref, settings.currency),
                  ),
                  KoinSettingTile(
                    title: 'Haptic feedback',
                    subtitle: 'Vibrations for selections and action results',
                    icon: KoinIcons.vibrate,
                    trailing: Switch(
                      value: settings.hapticsEnabled,
                      onChanged: (enabled) => ref
                          .read(settingsProvider.notifier)
                          .setHapticsEnabled(enabled),
                    ),
                  ),
                  KoinSettingTile(
                    title: 'Speech language',
                    subtitle: settings.voiceLocale == null
                        ? 'Follow system language'
                        : settings.voiceLocaleName ??
                              'Selected speech language',
                    icon: KoinIcons.microphone,
                    onTap: () => VoiceLanguageSheet.show(context),
                  ),
                  KoinSettingTile(
                    title: 'Manage archived items',
                    subtitle: 'Archive or restore accounts and categories',
                    icon: KoinIcons.archive,
                    onTap: () => Navigator.push(
                      context,
                      SlideUpRoute(page: const ArchiveManagerScreen()),
                    ),
                  ),
                ],
              ),
              const Gap(KoinSpacing.sectionGap),

              // ── Data Management ──
              const FormSectionTitle.subhead(
                title: 'Backup & recovery',
                padding: EdgeInsets.only(left: 4),
              ),
              const Gap(12),
              BackupRecoveryPanel(
                onExport: () => _handleBackup(context, ref),
                onImport: () => _handleRestore(context, ref),
              ),
              const Gap(KoinSpacing.sectionGap),

              // ── Danger Zone ──
              const FormSectionTitle.subhead(
                title: 'Danger Zone',
                padding: EdgeInsets.only(left: 4),
              ),
              const Gap(12),
              IgnorePointer(
                ignoring: _maintenanceBusy,
                child: KoinGroupedCard(
                  children: [
                    KoinSettingTile(
                      title: 'Delete All Records',
                      subtitle: 'Clear all your transaction history',
                      icon: KoinIcons.broom,
                      isDestructive: true,
                      onTap: () => _runMaintenanceAction(
                        () => _handleDeleteAllTransactions(context, ref),
                      ),
                    ),
                    KoinSettingTile(
                      title: 'Delete All Data',
                      subtitle: 'Clear all records, accounts, and categories',
                      icon: KoinIcons.trash,
                      isDestructive: true,
                      onTap: () => _runMaintenanceAction(
                        () => _handleDeleteAllData(context, ref),
                      ),
                    ),
                    KoinSettingTile(
                      title: 'Factory Reset',
                      subtitle: 'Reset app to its initial state',
                      icon: KoinIcons.clockCounterClockwise,
                      isDestructive: true,
                      onTap: () => _runMaintenanceAction(
                        () => _handleFactoryReset(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
              if (_maintenanceBusy) const LinearProgressIndicator(),
              const Gap(KoinSpacing.sectionGap),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBackup(BuildContext context, WidgetRef ref) async {
    try {
      final protection = await BackupPasswordSheet.show(context);
      if (protection == null || !context.mounted) return;
      final bundle = await ref.read(recoveryServiceProvider).exportBackup();

      if (bundle != null) {
        final bytes = protection.password == null
            ? await compute(compressBackup, bundle.bytes)
            : await BackupEncryption.encrypt(
                bundle.bytes,
                protection.password!,
              );
        if (!context.mounted) return;
        final savedPath = await FilePicker.saveFile(
          fileName: '${bundle.fileName}.koin',
          bytes: bytes,
        );

        if (context.mounted && savedPath != null) {
          KoinSnackBar.success(
            context,
            'Backup saved successfully',
            subtitle: 'Saved to the location you selected',
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
          subtitle:
              'Check available storage and folder access, then try again.',
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    try {
      final file = await FilePicker.pickFile();
      if (file != null) {
        if (!context.mounted) return;
        final confirmed = await _showConfirmationBottomSheet(
          context,
          title: 'Import this backup?',
          message:
              'Replace your current data with ${file.name}? A recovery copy of your current data will be kept first.',
          confirmText: 'Restore',
          icon: KoinIcons.downloadSimple,
          isDestructive: true,
        );
        if (confirmed != true) return;
        String? path = file.path;
        final stagedFiles = <File>[];
        try {
          if (path == null) {
            final bytes = await file.readAsBytes();
            final tempDir = await getTemporaryDirectory();
            final tempFile = File(
              p.join(
                tempDir.path,
                'koin_import_${DateTime.now().microsecondsSinceEpoch}.koin',
              ),
            );
            stagedFiles.add(tempFile);
            await tempFile.writeAsBytes(bytes);
            path = tempFile.path;
          }

          final encoded = await File(path).readAsBytes();
          if (BackupEncryption.isEncrypted(encoded)) {
            if (!context.mounted) return;
            final result = await BackupPasswordSheet.show(
              context,
              encrypted: encoded,
            );
            if (result?.unlocked == null || !context.mounted) return;
            final tempDir = await getTemporaryDirectory();
            final unlocked = File(
              p.join(
                tempDir.path,
                'koin_unlocked_${DateTime.now().microsecondsSinceEpoch}.db',
              ),
            );
            stagedFiles.add(unlocked);
            await unlocked.writeAsBytes(result!.unlocked!, flush: true);
            path = unlocked.path;
          }

          final success = await ref.read(recoveryServiceProvider).restore(path);

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
          for (final tempFile in stagedFiles) {
            try {
              if (await tempFile.exists()) await tempFile.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        KoinSnackBar.error(
          context,
          'Error restoring data',
          subtitle: 'Choose a valid Koin backup and check available storage, then try again.',
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
      message: 'Delete all transactions from your current data? Recovery copies and exported backups are kept.',
      confirmText: 'Delete',
      icon: KoinIcons.broom,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(recoveryServiceProvider)
          .runMaintenance(ref.read(appMaintenanceProvider).clearTransactions);

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
      message: 'Delete all transactions, savings logs, accounts, and categories from your current data? Recovery copies and exported backups are kept.',
      confirmText: 'Delete Data',
      icon: KoinIcons.trash,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(recoveryServiceProvider)
          .runMaintenance(ref.read(appMaintenanceProvider).clearAllData);

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
      message: 'Reset your current database and settings to their initial state? Recovery copies and exported backups are kept.',
      confirmText: 'Factory Reset',
      icon: KoinIcons.clockCounterClockwise,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(recoveryServiceProvider)
          .runMaintenance(ref.read(appMaintenanceProvider).factoryReset);

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
    return ConfirmationSheet.show(
      context: context,
      title: title,
      description: message,
      confirmLabel: confirmText,
      confirmColor: isDestructive
          ? AppTheme.errorColor(context)
          : AppTheme.primaryColor(context),
      icon: icon,
      isDanger: isDestructive,
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
      builder: (context) => KoinSheetSurface(
        height: MediaQuery.of(context).size.height * 0.7,
        color: AppTheme.surfaceColor(context),

        child: Column(
          children: [
            const KoinBottomSheetHandle(
              padding: EdgeInsets.only(top: 12, bottom: 20),
            ),
            const Text(
              'Select Currency',
              style: TextStyle(
                fontSize: KoinTypography.sectionTitle,
                letterSpacing: KoinTypography.headingTracking,
                fontWeight: KoinTypography.titleWeight,
              ),
            ),
            const Gap(20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: KoinSpacing.screenInset,
                ),
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
                          ? AppTheme.primaryColor(context)
                                .withValues(alpha: 0.08)
                          : AppTheme.surfaceLightColor(context),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () async {
                          if (isSelected) {
                            Navigator.pop(context);
                            return;
                          }
                          final confirmed = await ConfirmationSheet.show(
                            context: context,
                            title: 'Change currency to ${currency.code}?',
                            description:
                                'Existing amounts will keep the same numbers and use ${currency.code}. No exchange-rate conversion is applied.',
                            confirmLabel: 'Change currency',
                            confirmColor: AppTheme.primaryColor(context),
                            icon: KoinIcons.currencyCircleDollar,
                          );
                          if (confirmed != true || !context.mounted) return;
                          HapticService.light();
                          await ref
                              .read(settingsProvider.notifier)
                              .setCurrency(currency);
                          if (context.mounted) Navigator.pop(context);
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
                              fontSize: KoinTypography.itemTitle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          currency.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : KoinTypography.labelWeight,
                            color: isSelected
                                ? AppTheme.primaryColor(context)
                                : AppTheme.textColor(context),
                            fontSize: KoinTypography.body,
                          ),
                        ),
                        subtitle: Text(
                          currency.code,
                          style: TextStyle(
                            fontSize: KoinTypography.small,
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                KoinIcons.checkCircle,
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
      builder: (context) => KoinSheetSurface(
        padding: const EdgeInsets.only(
          bottom: 32,
          left: KoinSpacing.screenInset,
          right: KoinSpacing.screenInset,
          top: 12,
        ),
        color: AppTheme.surfaceColor(context),
        shadows: [
          AppTheme.boxShadow(
            context,
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KoinBottomSheetHandle(padding: EdgeInsets.only(bottom: 24)),
            Text(
              'App Appearance',
              style: TextStyle(
                fontSize: KoinTypography.screenTitle,
                fontWeight: KoinTypography.headingWeight,
                color: AppTheme.textColor(context),
                letterSpacing: KoinTypography.headingTracking,
              ),
            ),
            const Gap(8),
            Text(
              'Choose how Koin looks to you',
              style: TextStyle(
                fontSize: KoinTypography.compact,
                color: AppTheme.textLightColor(context),
                fontWeight: KoinTypography.supportingWeight,
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
                            icon: KoinIcons.circleHalf,
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
                            icon: KoinIcons.sun,
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
                            icon: KoinIcons.moon,
                            mode: ThemeMode.dark,
                            isSelected: currentMode == ThemeMode.dark,
                          ),
                        ),
                      ]
                      .koinAnimate(
                        context,
                        autoPlay: !MediaQuery.disableAnimationsOf(context),
                        onInit: KoinMotion.onInit(context),
                        interval: KoinMotion.duration(context, 40.ms),
                      )
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
    final isDark = AppTheme.hasEditorAppearance(context);

    return GestureDetector(
      onTap: () {
        HapticService.light();
        ref.read(settingsProvider.notifier).setThemeMode(mode);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: KoinMotion.duration(
          context,
          const Duration(milliseconds: 300),
        ),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected && !isDark
              ? primaryColor.withValues(alpha: 0.08)
              : surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? primaryColor.withValues(alpha: isDark ? 0.7 : 1)
                : AppTheme.fieldBorderColor(context, lightOpacity: 1),
            width: isSelected ? (isDark ? 1.5 : 2) : 1,
          ),
          boxShadow: isSelected
              ? [
                  AppTheme.boxShadow(
                    context,
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
              duration: KoinMotion.duration(
                context,
                const Duration(milliseconds: 300),
              ),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected && !isDark ? primaryColor : surfaceColor,
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(
                        color: AppTheme.dividerColor(context)
                            .withValues(alpha: 0.5),
                        width: 1.5,
                      ),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? (isDark ? primaryColor : Colors.white)
                    : AppTheme.textLightColor(context),
                size: 28,
              ),
            ),
            const Gap(16),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected
                    ? KoinTypography.headingWeight
                    : KoinTypography.labelWeight,
                color: isSelected ? primaryColor : AppTheme.textColor(context),
                fontSize: KoinTypography.compact,
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
