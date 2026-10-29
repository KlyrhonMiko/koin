import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DevicePrivacy {
  static const channel = MethodChannel('koin/device_privacy');
  bool authenticated = false;
  bool authenticating = false;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> authenticate() async {
    authenticating = true;
    try {
      authenticated = await channel.invokeMethod<bool>('authenticate') ?? false;
      return authenticated;
    } finally {
      authenticating = false;
    }
  }

  Future<void> setProtected(bool enabled) =>
      channel.invokeMethod<void>('setProtected', {'enabled': enabled});
}

final devicePrivacyProvider = Provider((ref) => DevicePrivacy());
