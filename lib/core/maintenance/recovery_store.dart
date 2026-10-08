import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class RecoveryCopy {
  const RecoveryCopy(this.path, this.createdAt, this.bytes);
  final String path;
  final DateTime createdAt;
  final int bytes;
}

/// Only manages files with our own name pattern in a dedicated directory.
class RecoveryStore {
  RecoveryStore(this.directory);
  final Directory directory;
  static final namePattern = RegExp(r'^koin_recovery_(\d+)\.koin$');

  Future<List<RecoveryCopy>> list() async {
    if (!await directory.exists()) return [];
    final copies = <RecoveryCopy>[];
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final match = namePattern.firstMatch(p.basename(entry.path));
      if (match == null) continue;
      copies.add(
        RecoveryCopy(
          entry.path,
          DateTime.fromMicrosecondsSinceEpoch(int.parse(match[1]!)),
          await entry.length(),
        ),
      );
    }
    copies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copies;
  }

  Future<RecoveryCopy?> save(Uint8List database, {DateTime? now}) async {
    await directory.create(recursive: true);
    // Remove only our abandoned staging files from interrupted writes.
    await for (final entry in directory.list()) {
      final name = p.basename(entry.path);
      if (entry is File &&
          name.endsWith('.partial') &&
          namePattern.hasMatch(
            name.substring(0, name.length - '.partial'.length),
          )) {
        await entry.delete();
      }
    }
    final copies = await list();
    if (copies.isNotEmpty) {
      try {
        final previous = await File(copies.first.path).readAsBytes();
        if (listEquals(gzip.decode(previous), database)) return null;
      } on FormatException {
        // A damaged prior copy must not prevent creating a new healthy one.
      }
    }
    final compressed = await compute(compressBackup, database);
    final createdAt = now ?? DateTime.now();
    final path = p.join(
      directory.path,
      'koin_recovery_${createdAt.microsecondsSinceEpoch}.koin',
    );
    final staged = File('$path.partial');
    try {
      await staged.writeAsBytes(compressed, flush: true);
      if (!listEquals(gzip.decode(await staged.readAsBytes()), database)) {
        throw const FormatException('Backup verification failed');
      }
      await staged.rename(path);
      // A failed write never removes the existing recovery copies.
      for (final old in (await list()).skip(3)) {
        await File(old.path).delete();
      }
      return RecoveryCopy(path, createdAt, compressed.length);
    } finally {
      if (await staged.exists()) await staged.delete();
    }
  }
}

Uint8List compressBackup(Uint8List bytes) =>
    Uint8List.fromList(gzip.encode(bytes));

Uint8List decodeBackup(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    return Uint8List.fromList(gzip.decode(bytes));
  }
  return bytes; // Existing .db exports remain supported.
}
