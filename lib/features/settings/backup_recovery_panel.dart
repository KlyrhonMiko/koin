import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/maintenance/recovery_service.dart';
import 'package:koin/core/maintenance/recovery_store.dart';

class BackupRecoveryPanel extends ConsumerStatefulWidget {
  const BackupRecoveryPanel({
    super.key,
    required this.onExport,
    required this.onImport,
  });
  final Future<void> Function() onExport;
  final Future<void> Function() onImport;

  @override
  ConsumerState<BackupRecoveryPanel> createState() =>
      _BackupRecoveryPanelState();
}

class _BackupRecoveryPanelState extends ConsumerState<BackupRecoveryPanel> {
  bool _acting = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(
          context,
          'Backup could not finish',
          subtitle:
              'Check available storage and folder access, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  String _date(DateTime date) => DateFormat.yMMMd().add_jm().format(date);

  Future<void> _restoreCopy(RecoveryService service, RecoveryCopy copy) async {
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Restore recovery copy?',
      description:
          'Replace your current data with the copy from ${_date(copy.createdAt)}? A recovery copy of your current data will be kept first.',
      confirmLabel: 'Restore',
      confirmColor: Theme.of(context).colorScheme.error,
      icon: Icons.restore_rounded,
      isDanger: true,
    );
    if (confirmed != true) return;
    final success = await service.restore(copy.path);
    if (!mounted) return;
    if (success) {
      KoinSnackBar.success(context, 'Recovery copy restored');
    } else {
      KoinSnackBar.error(
        context,
        'Could not restore this copy',
        subtitle: 'Try another recovery copy or import a backup.',
      );
    }
  }

  Future<void> _chooseCopy(
    RecoveryService service,
    List<RecoveryCopy> copies,
  ) async {
    final copy = await showModalBottomSheet<RecoveryCopy>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a recovery copy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final copy in copies)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(_date(copy.createdAt)),
                  subtitle: Text(_size(copy.bytes)),
                  onTap: () => Navigator.pop(context, copy),
                ),
            ],
          ),
        ),
      ),
    );
    if (copy != null && mounted) await _restoreCopy(service, copy);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(recoveryServiceProvider);
    return ValueListenableBuilder<RecoveryStatus>(
      valueListenable: service.status,
      builder: (context, status, _) {
        final busy = status.busy || _acting;
        final colors = Theme.of(context).colorScheme;
        final latest = status.copies.isEmpty ? null : status.copies.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KoinGroupedCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          status.localError
                              ? 'Recovery copy needs attention'
                              : status.busy
                              ? 'Saving recovery copy…'
                              : latest == null
                              ? 'Preparing your first recovery copy'
                              : 'Local recovery is on',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        latest == null
                            ? 'Koin saves copies automatically while you use the app.'
                            : 'Last copy: ${_date(latest.createdAt)}\n${status.copies.length} of 3 copies · ${_size(status.storageBytes)}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      if (status.localError) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Check free space on your device, then try again.',
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _run(() => service.check(force: true)),
                          child: const Text('Try again'),
                        ),
                      ],
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore a recovery copy'),
                  subtitle: Text(
                    latest == null
                        ? 'Available after the first copy is saved'
                        : 'Choose from your recent copies',
                  ),
                  enabled: latest != null && !busy,
                  onTap: latest == null || busy
                      ? null
                      : () => _run(() => _chooseCopy(service, status.copies)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'These copies stay on this device and may be removed when Koin is uninstalled. Keep a backup on another device to protect against losing this one.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            KoinGroupedCard(
              children: [
                if (service.external.supported) ...[
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(
                      status.destinationLabel == null
                          ? 'Set up folder backup'
                          : 'Backup folder: ${status.destinationLabel}',
                    ),
                    subtitle: Text(
                      status.externalError
                          ? 'Folder unavailable. Reconnect it or choose another folder.'
                          : status.destinationLabel == null
                          ? 'Choose a local folder or USB drive once'
                          : status.externalAt == null
                          ? 'Waiting for the first folder backup'
                          : 'Last backup: ${_date(status.externalAt!)}',
                    ),
                    enabled: !busy,
                    onTap: busy
                        ? null
                        : () => _run(() async {
                            await service.setupExternal();
                          }),
                  ),
                  if (status.destinationLabel != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => _run(() => service.check(force: true)),
                            child: const Text('Back up now'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => _run(service.disconnectExternal),
                            child: const Text('Disconnect folder'),
                          ),
                        ],
                      ),
                    ),
                ],
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: const Text('Export a backup'),
                  subtitle: const Text(
                    'Save a compressed copy to a location you choose',
                  ),
                  enabled: !busy,
                  onTap: busy ? null : () => _run(widget.onExport),
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Import a backup'),
                  subtitle: const Text(
                    'Restore a Koin backup or an earlier .db export',
                  ),
                  enabled: !busy,
                  onTap: busy ? null : () => _run(widget.onImport),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
