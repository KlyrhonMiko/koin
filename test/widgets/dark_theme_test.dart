import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + 0.05) / (second + 0.05)
      : (second + 0.05) / (first + 0.05);
}

void main() {
  testWidgets('dark mode preserves chosen accents with readable foregrounds', (
    tester,
  ) async {
    for (final accent in AppTheme.accentColors) {
      final theme = AppTheme.getTheme(accent, true);
      final scheme = theme.colorScheme;
      expect(scheme.primary, accent);
      expect(AppTheme.getTheme(accent, false).colorScheme.primary, accent);
      expect(
        contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(scheme.onError, scheme.error), greaterThanOrEqualTo(4.5));
      expect(
        contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onSurfaceVariant, scheme.surfaceContainerHigh),
        greaterThanOrEqualTo(4.5),
      );

      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(accent),
          theme: theme,
          home: Builder(
            builder: (context) {
              final fill = AppTheme.primaryGradient(context);
              expect(fill.colors, [accent, accent.withValues(alpha: 0.8)]);
              return const SizedBox();
            },
          ),
        ),
      );
    }
  });

  testWidgets('light gradients preserve their selected colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(Colors.teal, false),
        home: Builder(
          builder: (context) {
            expect(AppTheme.primaryGradient(context).colors, [
              Colors.teal,
              Colors.teal.withValues(alpha: 0.8),
            ]);
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
