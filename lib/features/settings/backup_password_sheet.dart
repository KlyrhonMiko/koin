import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/maintenance/backup_encryption.dart';

class BackupPasswordResult {
  const BackupPasswordResult({this.password, this.unlocked});
  final String? password;
  final Uint8List? unlocked;
}

class BackupPasswordSheet extends StatefulWidget {
  const BackupPasswordSheet({super.key, this.encrypted});
  final Uint8List? encrypted;

  static Future<BackupPasswordResult?> show(
    BuildContext context, {
    Uint8List? encrypted,
  }) => showModalBottomSheet<BackupPasswordResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BackupPasswordSheet(encrypted: encrypted),
  );

  @override
  State<BackupPasswordSheet> createState() => _BackupPasswordSheetState();
}

class _BackupPasswordSheetState extends State<BackupPasswordSheet> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _protect = true;
  bool _busy = false;
  String? _error;
  bool get _unlock => widget.encrypted != null;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final password = _password.text;
    if ((_unlock && password.isEmpty) ||
        (!_unlock &&
            _protect &&
            (password.length < 8 || password.trim().isEmpty))) {
      setState(
        () => _error = _unlock
            ? 'Enter the backup password'
            : 'Use at least 8 characters',
      );
      return;
    }
    if (!_unlock && _protect && password != _confirmation.text) {
      setState(() => _error = 'The passwords do not match');
      return;
    }
    if (!_unlock) {
      Navigator.pop(
        context,
        BackupPasswordResult(password: _protect ? password : null),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await BackupEncryption.decrypt(widget.encrypted!, password);
      if (mounted) {
        Navigator.pop(context, BackupPasswordResult(unlocked: bytes));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BackupUnlockException
              ? error.toString()
              : 'Could not unlock this backup. Check the file and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => KoinFormTheme(
    builder: (context) => PopScope(
      canPop: !_busy,
      child: KoinSheetSurface(
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KoinBottomSheetHandle(),
                  Text(
                    _unlock ? 'Unlock backup' : 'Protect your backup',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _unlock
                        ? 'Enter the password used when this backup was exported.'
                        : 'A password keeps exported financial records private. Keep it somewhere safe; Koin cannot recover it.',
                  ),
                  if (!_unlock) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Password protect this backup'),
                      value: _protect,
                      onChanged: (value) => setState(() {
                        _protect = value;
                        _error = null;
                      }),
                    ),
                  ],
                  if (_unlock || _protect) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: 'Password'),
                      onSubmitted: _unlock ? (_) => _submit() : null,
                    ),
                    if (!_unlock) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmation,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppTheme.errorContentColor(context),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  KoinPrimaryButton(
                    label: _unlock ? 'Unlock' : 'Continue',
                    isLoading: _busy,
                    onPressed: _submit,
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
