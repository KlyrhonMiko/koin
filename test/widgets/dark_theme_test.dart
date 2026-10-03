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
      expect(
        theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
        accent,
      );
      expect(theme.floatingActionButtonTheme.backgroundColor, accent);
      expect(scheme.error, const Color(0xFFFF6B6B));
      expect(scheme.secondary, const Color(0xFF34D399));
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
              expect(AppTheme.incomeColor(context), const Color(0xFF00D09E));
              expect(AppTheme.expenseColor(context), const Color(0xFFFF6B6B));
              expect(AppTheme.transferColor(context), const Color(0xFF3B82F6));
              final fill = AppTheme.primaryGradient(context);
              expect(fill.colors, [accent, accent.withValues(alpha: 0.8)]);
              final shadow = AppTheme.boxShadow(
                context,
                color: accent.withValues(alpha: 0.4),
                blurRadius: 20,
              );
              expect(shadow.color, Colors.black.withValues(alpha: 0.12));
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
            expect(
              AppTheme.boxShadow(
                context,
                color: Colors.teal.withValues(alpha: 0.3),
              ).color,
              Colors.teal.withValues(alpha: 0.3),
            );
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
