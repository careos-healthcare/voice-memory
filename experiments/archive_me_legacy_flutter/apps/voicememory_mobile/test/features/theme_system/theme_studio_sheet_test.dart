import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/theme_system/theme_engine.dart';
import 'package:voicememory_mobile/features/theme_system/theme_models.dart';
import 'package:voicememory_mobile/features/theme_system/ui/theme_studio_sheet.dart';
import 'package:voicememory_mobile/features/theme_system/visual_theme_tokens.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  testWidgets('switches presets live and resets persisted controls', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('theme-studio-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final prefsFile = File('${directory.path}/prefs.json')
      ..writeAsStringSync('{}');
    final store = ThemePreferencesStore(MobilePrefsStore(file: prefsFile));

    await tester.binding.setSurfaceSize(const Size(520, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [themePreferencesStoreProvider.overrideWithValue(store)],
        child: const _Harness(),
      ),
    );

    expect(find.byKey(const Key('theme_live_preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('theme_preset_obsidian')));
    await tester.pump(const Duration(milliseconds: 250));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ThemeStudioSheet)),
    );
    expect(
      container.read(themeEngineProvider).archetype,
      ThemeArchetype.obsidian,
    );

    final blurSlider = find.byKey(const Key('theme_blur_slider'));
    await tester.ensureVisible(blurSlider);
    await tester.pump();
    await tester.drag(blurSlider, const Offset(100, 0));
    await tester.pump();
    expect(
      container.read(themeEngineProvider).glassBlur,
      isNot(ThemePreferences.defaultPreferences.glassBlur),
    );

    await tester.ensureVisible(find.byKey(const Key('theme_reset_button')));
    await tester.tap(find.byKey(const Key('theme_reset_button')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      container.read(themeEngineProvider),
      ThemePreferences.defaultPreferences,
    );
  });

  testWidgets('remains usable with large accessibility text', (tester) async {
    final directory = Directory.systemTemp.createTempSync('theme-text-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final prefsFile = File('${directory.path}/prefs.json')
      ..writeAsStringSync('{}');
    final store = ThemePreferencesStore(MobilePrefsStore(file: prefsFile));
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [themePreferencesStoreProvider.overrideWithValue(store)],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _Harness(),
        ),
      ),
    );
    expect(find.text('Theme Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(themeEngineProvider);
    final tokens = VisualThemeTokens.resolve(preferences, Brightness.dark);
    return MaterialApp(
      theme: AppTheme.fromTokens(tokens),
      home: const Scaffold(body: ThemeStudioSheet()),
    );
  }
}
