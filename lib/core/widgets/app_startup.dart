import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Draws the first frame before database initialization starts.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.initialize});

  final Future<Widget> Function() initialize;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Widget? _app;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      final app = await widget.initialize();
      if (mounted) setState(() => _app = app);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Koin startup',
        ),
      );
      if (mounted) setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() => _failed = false);
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_app != null) return _app!;

    // Keep startup independent of downloaded fonts and database providers.
    ThemeData theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00D09E),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF171A1C)
          : const Color(0xFFF8F9FA),
    );

    return MaterialApp(
      title: 'Koin',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: dark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Theme.of(
                context,
              ).scaffoldBackgroundColor,
              systemNavigationBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
            child: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 64,
                        height: 64,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  if (!_failed)
                    Center(
                      child: Transform.translate(
                        offset: const Offset(0, 52),
                        child: Semantics(
                          label: 'Opening Koin',
                          liveRegion: true,
                          child: TickerMode(
                            enabled: !MediaQuery.disableAnimationsOf(context),
                            child: SizedBox(
                              width: 48,
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                borderRadius: BorderRadius.circular(1),
                                color: colors.onSurfaceVariant,
                                backgroundColor: colors.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Koin couldn’t open. Please try again.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.onSurface),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _retry,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
