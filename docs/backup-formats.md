# Backup formats

Manual export offers password protection. The password is used only for the export or import operation and is not stored in app preferences or included in a backup. Keep it somewhere safe: Koin cannot reset or recover it.

An import recognizes the format from file contents. Protected backups ask for a password, authenticate the data before attempting a restore, and allow a retry after an incorrect password. Cancelling or failing to unlock a file does not replace the current database. Normal restore still validates SQLite integrity and keeps a recovery copy of the current data first.

## Compatibility

- Existing uncompressed `.db` backups remain importable.
- Existing gzip-compressed `.koin` backups remain importable.
- New manual exports may use the protected format below, or retain the gzip format when protection is explicitly turned off.
- Automatic local recovery and folder backups remain gzip-compressed and unencrypted. The export password does not change those copies.
- Earlier Koin versions cannot read the new protected format. Import it with this version or later.

## Protected format, version 1

The implementation uses [cryptography](https://pub.dev/packages/cryptography) AES-256-GCM with a fresh random 16-byte salt and a fresh 12-byte nonce per export. A 256-bit key is derived from the password using PBKDF2-HMAC-SHA256 with 600,000 iterations. Compression precedes encryption. Derivation and encryption/decryption run outside the UI isolate.

| Bytes | Contents |
|---|---|
| 0-6 | ASCII `KOINENC` |
| 7 | Version `1` |
| 8-23 | Salt |
| 24-35 | Nonce |
| 36 through the last 16 bytes | Encrypted gzip payload |
| Last 16 bytes | Authentication tag |

All 36 header bytes are authenticated as associated data. The version determines the KDF cost; untrusted file contents cannot request arbitrary iteration counts. A wrong password or altered ciphertext fails authentication. Unsupported versions and truncated headers are rejected.

The UI stages a successfully unlocked database only in temporary app storage, invokes the normal recovery service, and removes staged import files afterwards. Password entry fields obscure input and disable suggestions/autocorrection.
