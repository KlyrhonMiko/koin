import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/maintenance/external_backup.dart';
import 'package:koin/core/maintenance/maintenance_manager.dart';
import 'package:koin/core/maintenance/recovery_service.dart';
import 'package:koin/core/maintenance/recovery_store.dart';
import 'package:koin/features/settings/backup_recovery_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvailableExternal extends ExternalBackup {
  @override
  bool get supported => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Load installed fonts for readable local preview artifacts when available.
    final fonts = {
      'PreviewSans': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons':
          'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    };
    for (final font in fonts.entries) {
      final file = File(font.value);
      if (await file.exists()) {
        final loader = FontLoader(font.key)
          ..addFont(
            file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    }
  });
  late RecoveryService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = RecoveryService(
      maintenance: InMemoryMaintenanceAdapter(),
      preferences: await SharedPreferences.getInstance(),
      changeToken: () async => '',
      store: () async => RecoveryStore(Directory('unused')),
      external: AvailableExternal(),
    );
  });
  tearDown(() => service.dispose());

  Future<void> render(
    WidgetTester tester, {
    required Size size,
    Brightness brightness = Brightness.light,
    double scale = 1,
    bool capture = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recoveryServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: brightness,
            fontFamily: 'PreviewSans',
          ),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup & recovery',
                          style: ThemeData(
                            fontFamily: 'PreviewSans',
                            brightness: brightness,
                          ).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        BackupRecoveryPanel(
                          onExport: () async {},
                          onImport: () async {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (capture) {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = await Directory(
          'build/backup-previews',
        ).create(recursive: true);
        await File(
          '${dir.path}/${brightness.name}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  }

  testWidgets('recovery states remain readable at small sizes and large text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final status in [
      const RecoveryStatus(),
      const RecoveryStatus(busy: true),
      const RecoveryStatus(
        localError: true,
        externalError: true,
        destinationLabel: 'A long removable USB drive folder name',
      ),
    ]) {
      service.status.value = status;
      await render(tester, size: const Size(375, 812), scale: 2);
      await render(
        tester,
        size: const Size(812, 375),
        brightness: Brightness.dark,
        scale: 2,
      );
    }
    service.status.value = RecoveryStatus(
      copies: [RecoveryCopy('test', DateTime(2026, 10, 8, 15, 40), 24000)],
    );
    expect(service.status.value.storageBytes, 24000);
    for (final brightness in Brightness.values) {
      await render(
        tester,
        size: const Size(375, 812),
        brightness: brightness,
        capture: true,
      );
      expect(find.text('Local recovery is on'), findsOneWidget);
      expect(find.textContaining('23.4 KB'), findsOneWidget);
    }
  });

  testWidgets('restore is disabled until a copy exists and during saving', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(tester, size: const Size(375, 812));
    ListTile tile() => tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Restore a recovery copy'),
    );
    expect(tile().enabled, isFalse);
    service.status.value = RecoveryStatus(
      copies: [RecoveryCopy('test', DateTime(2026), 100)],
    );
    await tester.pump();
    expect(tile().enabled, isTrue);
    service.status.value = RecoveryStatus(
      busy: true,
      copies: service.status.value.copies,
    );
    await tester.pump();
    expect(tile().enabled, isFalse);
  });
}
