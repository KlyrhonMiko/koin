import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  setUp(AnimationTracker.clear);

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
                    icons: const [KoinIcons.house, KoinIcons.briefcase],
                    selectedIcon: selected ? KoinIcons.briefcase : KoinIcons.house,
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

  testWidgets('reorder feedback drops zoom when reduced motion changes', (
    tester,
  ) async {
    var reduced = false;
    var progress = 0.5;
    late StateSetter redraw;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            redraw = setState;
            return MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: koinReorderProxyDecorator(
                const Text('Dragged item'),
                0,
                AlwaysStoppedAnimation(progress),
              ),
            );
          },
        ),
      ),
    );
    final transform = find
        .ancestor(
          of: find.text('Dragged item'),
          matching: find.byType(Transform),
        )
        .first;
    expect(
      tester.widget<Transform>(transform).transform.entry(0, 0),
      greaterThan(1),
    );

    redraw(() => reduced = true);
    await tester.pump();
    expect(tester.widget<Transform>(transform).transform.entry(0, 0), 1);
    redraw(() => progress = 0.9);
    await tester.pump();
    expect(tester.widget<Transform>(transform).transform.entry(0, 0), 1);
    expect(tester.takeException(), isNull);
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
