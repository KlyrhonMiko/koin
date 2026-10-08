import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges a Control Center tap after the app has finished initialization.
class QuickTransactionService {
  static const channel = MethodChannel('koin/quick_transaction');

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _disposed = false;

  Future<void> initialize(VoidCallback onAddTransaction) async {
    if (!isAndroid) return;
    channel.setMethodCallHandler((call) async {
      if (!_disposed && call.method == 'addTransaction') onAddTransaction();
    });
    try {
      final action = await channel.invokeMethod<String>('getLaunchAction');
      if (!_disposed && action == 'addTransaction') onAddTransaction();
    } on MissingPluginException {
      // Other platforms and older installed native builds have no bridge.
    } on PlatformException {
      // A shortcut failure must not prevent the main app from opening.
    }
  }

  static Future<String> addTile() async {
    if (!isAndroid) return 'unavailable';
    try {
      return await channel.invokeMethod<String>('addTile') ?? 'unavailable';
    } on MissingPluginException {
      return 'unavailable';
    } on PlatformException {
      return 'unavailable';
    }
  }

  void dispose() {
    _disposed = true;
    if (isAndroid) channel.setMethodCallHandler(null);
  }
}
