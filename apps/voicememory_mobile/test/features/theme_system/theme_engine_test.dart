import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/theme_system/theme_engine.dart';
import 'package:voicememory_mobile/features/theme_system/theme_models.dart';
import 'package:voicememory_mobile/features/theme_system/visual_theme_tokens.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  group('ThemeEngine', () {
    late Directory directory;
    late MobilePrefsStore prefs;
    late ThemePreferencesStore store;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('theme-engine-');
      prefs = await MobilePrefsStore.open('${directory.path}/prefs.json');
      store = ThemePreferencesStore(prefs);
      await store.initialize();
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('persists state across provider and store restarts', () async {
      var container = ProviderContainer(
        overrides: [themePreferencesStoreProvider.overrideWithValue(store)],
      );
      final engine = container.read(themeEngineProvider.notifier);
      await engine.selectArchetype(ThemeArchetype.obsidian);
      await engine.setCustomAccent(const Color(0xFF12D6A0));
      await engine.setGlassBlur(27);
      await engine.setGlassOpacity(.72);
      await engine.setNodeGlowDiffusion(1.2);
      await engine.setGlassEffects(GlassEffectPreference.reduced);
      await store.flush();
      container.dispose();

      final restarted = ThemePreferencesStore(
        await MobilePrefsStore.open('${directory.path}/prefs.json'),
      );
      await restarted.initialize();
      container = ProviderContainer(
        overrides: [themePreferencesStoreProvider.overrideWithValue(restarted)],
      );
      addTearDown(container.dispose);
      final restored = container.read(themeEngineProvider);
      expect(restored.archetype, ThemeArchetype.obsidian);
      expect(restored.customAccentValue, const Color(0xFF12D6A0).toARGB32());
      expect(restored.glassBlur, 27);
      expect(restored.glassOpacity, .72);
      expect(restored.nodeGlowDiffusion, 1.2);
      expect(restored.glassEffects, GlassEffectPreference.reduced);
    });

    test('clamps controls and resets unsupported schemas', () async {
      final clamped = ThemePreferences.fromJson({
        'schemaVersion': 1,
        'glassBlur': 999,
        'glassOpacity': 0,
        'nodeGlowDiffusion': -2,
      });
      expect(clamped.glassBlur, 30);
      expect(clamped.glassOpacity, .45);
      expect(clamped.nodeGlowDiffusion, 0);
      expect(
        ThemePreferences.fromJson({
          'schemaVersion': 99,
          'archetype': 'obsidian',
        }),
        ThemePreferences.defaultPreferences,
      );
    });

    test('archetypes resolve intended brightness and custom accent', () {
      final obsidian = VisualThemeTokens.resolve(
        const ThemePreferences(
          archetype: ThemeArchetype.obsidian,
          customAccentValue: 0xFF00FFAA,
        ),
        Brightness.light,
      );
      final parchment = VisualThemeTokens.resolve(
        const ThemePreferences(archetype: ThemeArchetype.parchment),
        Brightness.dark,
      );
      final dynamicDark = VisualThemeTokens.resolve(
        const ThemePreferences(),
        Brightness.dark,
      );
      expect(obsidian.brightness, Brightness.dark);
      expect(obsidian.background, Colors.black);
      expect(obsidian.accent, const Color(0xFF00FFAA));
      expect(parchment.brightness, Brightness.light);
      expect(dynamicDark.brightness, Brightness.dark);
      expect(themeModeFor(ThemeArchetype.dynamicSystem), ThemeMode.system);
    });
  });
}
