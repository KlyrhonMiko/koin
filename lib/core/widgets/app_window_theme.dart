import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps Android's exposed window background in sync with the Flutter theme.
/// Mini-window mode can expose it behind the system gesture-navigation area.
class AppWindowTheme extends StatefulWidget {
  const AppWindowTheme({super.key, required this.child});

  final Widget child;

  @override
  State<AppWindowTheme> createState() => _AppWindowThemeState();
}

class _AppWindowThemeState extends State<AppWindowTheme> {
  static const _channel = MethodChannel('koin/window_theme');
  Color? _background;
  bool? _dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final background = theme.scaffoldBackgroundColor;
    final dark = theme.brightness == Brightness.dark;
    if (background == _background && dark == _dark) return;
    _background = background;
    _dark = dark;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _syncWindow(background, dark);
    }
  }

  Future<void> _syncWindow(Color background, bool dark) async {
    try {
      await _channel.invokeMethod<void>('setTheme', {
        'backgroundColor': background.toARGB32(),
        'dark': dark,
      });
    } on MissingPluginException {
      // Widget previews and older native builds have no window-theme bridge.
    } on PlatformException {
      // A system-window styling failure must not interrupt the app.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
