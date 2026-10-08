import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'recovery_store.dart';

class BackupDestination {
  const BackupDestination(this.location, this.label);
  final String location;
  final String label;
}

class ExternalBackup {
  static const channel = MethodChannel('koin/backup');
  bool get supported =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  Future<BackupDestination?> choose() async {
    if (Platform.isAndroid) {
      final result = await channel.invokeMapMethod<String, String>(
        'chooseFolder',
      );
      if (result == null) return null;
      return BackupDestination(result['uri']!, result['label']!);
    }
    if (!supported) return null;
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a local backup folder',
    );
    return path == null ? null : BackupDestination(path, p.basename(path));
  }

  Future<void> write(String destination, RecoveryCopy copy) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('writeBackup', {
        'uri': destination,
        'name': p.basename(copy.path),
        'bytes': await File(copy.path).readAsBytes(),
      });
    } else {
      // Use a dedicated subfolder so pruning never touches user files.
      final store = RecoveryStore(
        Directory(p.join(destination, 'Koin backups')),
      );
      if (!await Directory(destination).exists()) {
        throw const FileSystemException('Folder unavailable');
      }
      await store.save(
        decodeBackup(await File(copy.path).readAsBytes()),
        now: copy.createdAt,
      );
    }
  }
}
