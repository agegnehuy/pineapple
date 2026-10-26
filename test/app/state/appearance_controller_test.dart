import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/appearance_controller.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/app_brand.dart';
import 'package:myoccasio/features/settings/presentation/appearance_screen.dart';

void main() {
  testWidgets('reduced motion bypasses both native platform page transitions', (
    tester,
  ) async {
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) => Column(
              children: [
                for (final platform in [
                  TargetPlatform.android,
                  TargetPlatform.iOS,
                ])
                  AppTheme.light.pageTransitionsTheme.builders[platform]!
                      .buildTransitions(
                        route,
                        context,
                        const AlwaysStoppedAnimation<double>(0.5),
                        const AlwaysStoppedAnimation<double>(0),
                        Text(platform.name),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      expect(
        find.ancestor(
          of: find.text(platform.name),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text(platform.name),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    }
  });
  test(
    'appearance survives a new controller without touching session state',
    () async {
      String? saved;
      final first = AppearanceController(
        read: () async => saved,
        write: (value) async => saved = value,
      );
      await first.setMode(ThemeMode.dark);
      final restored = AppearanceController(read: () async => saved);
      await restored.initialize();
      expect(restored.mode, ThemeMode.dark);
      first.dispose();
      restored.dispose();
    },
  );
  test(
    'late restoration does not overwrite the user’s new selection',
    () async {
      final read = Completer<String?>();
      final controller = AppearanceController(read: () => read.future);
      final load = controller.initialize();
      await controller.setMode(ThemeMode.system);
      read.complete('dark');
      await load;
      expect(controller.mode, ThemeMode.system);
      controller.dispose();
    },
  );
  test(
    'failed storage leaves the current appearance intact and permits retry',
    () async {
      var fail = true;
      final controller = AppearanceController(
        write: (_) async {
          if (fail) throw StateError('storage');
        },
      );
      await expectLater(controller.setMode(ThemeMode.dark), throwsStateError);
      expect(controller.mode, ThemeMode.light);
      fail = false;
      await controller.setMode(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);
      controller.dispose();
    },
  );
  test('dark text and error colors retain accessible contrast', () {
    final theme = AppTheme.dark;
    expect(
      theme.navigationBarTheme.iconTheme!.resolve({
        WidgetState.selected,
      })!.color,
      theme.colorScheme.primary,
    );
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
    }

    for (final color in [
      theme.colorScheme.onSurface,
      theme.colorScheme.onSurfaceVariant,
      theme.colorScheme.error,
      theme.colorScheme.primary,
    ]) {
      expect(
        contrast(color, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  testWidgets(
    'appearance changes the whole app theme and retains retry on save failure',
    (tester) async {
      var fail = true;
      final controller = AppearanceController(
        write: (_) async {
          if (fail) throw StateError('storage');
        },
      );
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: controller.mode,
            home: AppearanceScreen(controller: controller),
          ),
        ),
      );
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.light);
      expect(find.textContaining('Could not save'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppearanceScreen))).brightness,
        Brightness.dark,
      );
      expect(find.textContaining('Could not save'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: AppBrand()),
        ),
      );
      expect(
        tester.widget<Text>(find.text('MyOccasio')).style!.color,
        AppTheme.dark.colorScheme.onSurface,
      );
      expect(tester.takeException(), isNull);
      controller.dispose();
    },
  );
}
