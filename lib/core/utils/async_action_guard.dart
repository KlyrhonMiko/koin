import 'package:flutter/material.dart';
import 'snackbar_utils.dart';

/// Guards an entire confirmation/write flow, including duplicate requests.
class KoinAsyncActionGuard {
  bool _busy = false;
  Future<void> run(
    BuildContext context,
    Future<void> Function() action, {
    String errorTitle = 'Could not finish this action',
  }) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        KoinSnackBar.error(context, errorTitle, subtitle: 'Please try again.');
      }
    } finally {
      _busy = false;
    }
  }
}
