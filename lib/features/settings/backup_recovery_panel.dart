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
        final supporting = Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
        const inset = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        Widget divider() => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: AppTheme.dividerColor(context),
        );
        Widget action(
          String title,
          IconData icon,
          Future<void> Function() callback, {
          String? subtitle,
          bool enabled = true,
        }) => ListTile(
          contentPadding: inset,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle, style: supporting),
          trailing: Icon(icon, size: 20),
          enabled: enabled && !busy,
          onTap: enabled && !busy ? () => _run(callback) : null,
        );

        return KoinGroupedCard(
          autoDivide: false,
          children: [
            // Stretch the status block so its text starts at the card inset,
            // rather than centering an intrinsically sized column.
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status.localError
                            ? 'Backup needs attention'
                            : status.busy
                            ? 'Saving a backup…'
                            : 'Automatic backups',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest == null
                          ? 'Your first copy will be saved on this device.'
                          : 'On this device · ${DateFormat.MMMd().add_jm().format(latest.createdAt)}',
                      style: supporting,
                    ),
                    if (status.localError) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Check free space, then try again.',
                        style: supporting,
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
            ),
            divider(),
            action(
              'Restore data',
              Icons.restore_rounded,
              () => _chooseCopy(service, status.copies),
              enabled: latest != null,
              subtitle: latest == null
                  ? 'Available after the first backup'
                  : null,
            ),
            divider(),
            ExpansionTile(
              tilePadding: inset,
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: const Text('More backup options'),
              subtitle: status.externalError
                  ? Text('Folder backup needs attention', style: supporting)
                  : null,
              children: [
                if (service.external.supported) ...[
                  action(
                    status.destinationLabel == null
                        ? 'Choose a backup folder'
                        : 'Change backup folder',
                    Icons.folder_outlined,
                    () async {
                      await service.setupExternal();
                    },
                    subtitle: status.externalError
                        ? 'Reconnect your folder or choose another.'
                        : status.destinationLabel ??
                              'Optional · local folder or USB drive',
                  ),
                  if (status.destinationLabel != null) ...[
                    if (status.externalAt != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            'Folder updated ${_date(status.externalAt!)}',
                            style: supporting,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        _run(() => service.check(force: true)),
                              child: const Text('Back up now'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => _run(service.disconnectExternal),
                              child: const Text('Disconnect'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                action(
                  'Export a backup',
                  Icons.upload_file_rounded,
                  widget.onExport,
                ),
                action(
                  'Import a backup',
                  Icons.download_rounded,
                  widget.onImport,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      '${status.copies.length} of 3 copies · ${_size(status.storageBytes)}\n'
                      'Local copies may be removed on uninstall. Keep an exported copy on another device in case you lose this one.',
                      style: supporting,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
