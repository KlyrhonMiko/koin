import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/coach/stash_coach_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(AnimationTracker.clear);

  testWidgets(
    'stash coach switches controls together without retaining old actions',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(
            theme: AppTheme.getTheme(Colors.teal, false),
            home: StashCoachView(
              goal: SavingsGoal(
                id: 'stash-motion',
                name: 'Stash',
                startDate: DateTime(2026),
                currentAmount: 100,
                isStash: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Target Amount', 'Target Date', 'Target Amount']) {
        await tester.tap(find.text(label));
        await tester.pump();
        expect(
          find.text(
            label == 'Target Amount'
                ? 'Adjust Target Amount'
                : 'Adjust Target Date',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            label == 'Target Amount'
                ? 'Adjust Target Date'
                : 'Adjust Target Amount',
          ),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('entrance preserves child state across refresh and disabling', (
    tester,
  ) async {
    var enabled = true;
    late StateSetter redraw;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            redraw = setState;
            return const _StatefulProbe().koinEntrance(
              context,
              token: 'refresh',
              enabled: enabled,
            );
          },
        ),
      ),
    );
    final original = tester.state(find.byType(_StatefulProbe));
    await tester.pump(const Duration(milliseconds: 80));
    final fade = find
        .ancestor(
          of: find.byType(_StatefulProbe),
          matching: find.byType(FadeTransition),
        )
        .first;
    final beforeRefresh = tester.widget<FadeTransition>(fade).opacity.value;
    expect(beforeRefresh, inExclusiveRange(0, 1));
    redraw(() {});
    await tester.pump();
    expect(tester.widget<FadeTransition>(fade).opacity.value, beforeRefresh);
    redraw(() => enabled = false);
    await tester.pump();
    expect(tester.state(find.byType(_StatefulProbe)), same(original));
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
  });

  testWidgets('seen rows do not replay when remounted', (tester) async {
    Widget row() => MaterialApp(
      home: Builder(
        builder: (context) =>
            const _StatefulProbe().koinEntrance(context, token: 'row'),
      ),
    );
    await tester.pumpWidget(row());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(row());
    final fade = find
        .ancestor(
          of: find.byType(_StatefulProbe),
          matching: find.byType(FadeTransition),
        )
        .first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'reduced motion finishes an entrance without replacing its child',
    (tester) async {
      var reduced = false;
      late StateSetter redraw;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              redraw = setState;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: Builder(
                  builder: (context) =>
                      const _StatefulProbe().koinEntrance(context),
                ),
              );
            },
          ),
        ),
      );
      final original = tester.state(find.byType(_StatefulProbe));
      await tester.pump(const Duration(milliseconds: 40));
      redraw(() => reduced = true);
      await tester.pump();
      final scale = find
          .ancestor(
            of: find.byType(_StatefulProbe),
            matching: find.byType(ScaleTransition),
          )
          .first;
      expect(tester.widget<ScaleTransition>(scale).scale.value, 1);
      expect(tester.state(find.byType(_StatefulProbe)), same(original));
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('palette changes use no scale tween under reduced motion', (
    tester,
  ) async {
    var selected = false;
    late StateSetter redraw;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) {
              redraw = setState;
              return Column(
                children: [
                  ColorPaletteGrid(
                    colors: const [Colors.teal, Colors.red],
                    selectedColor: selected ? Colors.red : Colors.teal,
                    isScrollableRow: true,
                  ),
                  IconPaletteGrid(
                    icons: const [Icons.home, Icons.work],
                    selectedIcon: selected ? Icons.work : Icons.home,
                    activeColor: Colors.teal,
                    isScrollableRow: true,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    redraw(() => selected = true);
    await tester.pump();
    for (final scale in tester.widgetList<AnimatedScale>(
      find.byType(AnimatedScale),
    )) {
      expect(scale.duration, Duration.zero);
    }
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('confirmation actions are visible from the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConfirmationSheet(
            title: 'Delete?',
            description: 'Delete this item?',
            confirmLabel: 'Delete',
            confirmColor: Colors.red,
            icon: Icons.delete,
            isDanger: true,
          ),
        ),
      ),
    );
    for (final label in ['Cancel', 'Delete']) {
      final ancestors = find.ancestor(
        of: find.text(label),
        matching: find.byType(FadeTransition),
      );
      for (final fade in tester.widgetList<FadeTransition>(ancestors)) {
        expect(fade.opacity.value, 1);
      }
    }
    await tester.pumpAndSettle();
  });
}

class _StatefulProbe extends StatefulWidget {
  const _StatefulProbe();

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  @override
  Widget build(BuildContext context) => const Text('Stable child');
}
