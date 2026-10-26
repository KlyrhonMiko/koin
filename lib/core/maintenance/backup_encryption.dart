import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'recovery_store.dart';

class BackupUnlockException implements Exception {
  const BackupUnlockException();
  @override
  String toString() => 'Incorrect password or damaged backup. Try again.';
}

/// Version 1: magic/version (8), random salt (16), nonce (12), ciphertext,
/// and GCM tag (16). All header bytes are authenticated. KDF cost is fixed by
/// the version rather than controlled by untrusted file contents.
abstract final class BackupEncryption {
  static const header = [0x4b, 0x4f, 0x49, 0x4e, 0x45, 0x4e, 0x43, 1];
  static const iterations = 600000;

  static bool isEncrypted(List<int> bytes) =>
      bytes.length >= 7 &&
      List.generate(7, (i) => bytes[i] == header[i]).every((equal) => equal);

  static Future<Uint8List> encrypt(Uint8List bytes, String password) =>
      compute(_encrypt, (bytes, password));

  static Future<Uint8List> decrypt(Uint8List bytes, String password) =>
      compute(_decrypt, (bytes, password));

  static Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  static Future<Uint8List> _encrypt((Uint8List, String) input) async {
    final (bytes, password) = input;
    if (password.length < 8 || password.trim().isEmpty) {
      throw ArgumentError('Use a password with at least 8 characters');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final cipher = AesGcm.with256bits();
    final nonce = cipher.newNonce();
    final metadata = [...header, ...salt, ...nonce];
    final box = await cipher.encrypt(
      compressBackup(bytes),
      secretKey: await _key(password, salt),
      nonce: nonce,
      aad: metadata,
    );
    return Uint8List.fromList([
      ...metadata,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  static Future<Uint8List> _decrypt((Uint8List, String) input) async {
    final (bytes, password) = input;
    if (!isEncrypted(bytes)) return decodeBackup(bytes);
    if (bytes.length < 52 || bytes[7] != 1) {
      throw const FormatException('Unsupported or incomplete encrypted backup');
    }
    final metadata = bytes.sublist(0, 36);
    final salt = bytes.sublist(8, 24);
    final nonce = bytes.sublist(24, 36);
    final box = SecretBox(
      bytes.sublist(36, bytes.length - 16),
      nonce: nonce,
      mac: Mac(bytes.sublist(bytes.length - 16)),
    );
    try {
      final compressed = await AesGcm.with256bits().decrypt(
        box,
        secretKey: await _key(password, salt),
        aad: metadata,
      );
      return decodeBackup(Uint8List.fromList(compressed));
    } on SecretBoxAuthenticationError {
      throw const BackupUnlockException();
    }
  }
}
