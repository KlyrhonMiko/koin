import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/maintenance/backup_encryption.dart';
import 'package:koin/core/maintenance/recovery_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final original = Uint8List.fromList(
    utf8.encode('SQLite test payload \u20b1'),
  );
  const password = 'example test password';
  late Uint8List encrypted;
  setUpAll(() async {
    encrypted = await BackupEncryption.encrypt(original, password);
  });
  test('protected backup round trips and does not contain plaintext', () async {
    expect(BackupEncryption.isEncrypted(encrypted), true);
    expect(await BackupEncryption.decrypt(encrypted, password), original);
    expect(
      utf8
          .decode(encrypted, allowMalformed: true)
          .contains('SQLite test payload'),
      false,
    );
  });
  test('wrong password leaves the encrypted file unchanged', () async {
    final before = Uint8List.fromList(encrypted);
    await expectLater(
      BackupEncryption.decrypt(encrypted, 'incorrect password'),
      throwsA(isA<BackupUnlockException>()),
    );
    expect(encrypted, before);
  });
  test('authentication rejects modified metadata and ciphertext', () async {
    final modified = Uint8List.fromList(encrypted)..[36] ^= 1;
    await expectLater(
      BackupEncryption.decrypt(modified, password),
      throwsA(isA<BackupUnlockException>()),
    );
    final incomplete = Uint8List.fromList(encrypted.take(20).toList());
    await expectLater(
      BackupEncryption.decrypt(incomplete, password),
      throwsFormatException,
    );
  });
  test(
    'legacy compressed and database backups still decode without a password',
    () async {
      final compressed = compressBackup(original);
      expect(BackupEncryption.isEncrypted(compressed), false);
      expect(await BackupEncryption.decrypt(compressed, ''), original);
      expect(await BackupEncryption.decrypt(original, ''), original);
    },
  );
}
