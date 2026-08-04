import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'theme_models.dart';
import 'visual_theme_tokens.dart';

final class ThemePreferencesStore {
  ThemePreferencesStore(this._prefs);

  static const preferencesKey = 'visualThemePreferencesV1';

  final MobilePrefsStore _prefs;
  ThemePreferences _current = ThemePreferences.defaultPreferences;
  Future<void> _writeTail = Future<void>.value();

  ThemePreferences get current => _current;

  Future<ThemePreferences> initialize() async {
    final raw = await _prefs.readMap(preferencesKey);
    try {
      _current = raw == null
          ? ThemePreferences.defaultPreferences
          : ThemePreferences.fromJson(raw);
    } on Object {
      _current = ThemePreferences.defaultPreferences;
    }
    return _current;
  }

  Future<void> save(ThemePreferences preferences) {
    _current = preferences;
    final completer = Completer<void>();
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      try {
        await _prefs.writeMap(preferencesKey, preferences.toJson());
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> flush() => _writeTail;
}

final themePreferencesStoreProvider = Provider<ThemePreferencesStore>((ref) {
  return AppServices.instance.themePreferencesStore;
});

final class ThemeEngine extends Notifier<ThemePreferences> {
  ThemePreferencesStore get _store => ref.read(themePreferencesStoreProvider);

  @override
  ThemePreferences build() => _store.current;

  Future<void> selectArchetype(ThemeArchetype archetype) =>
      _commit(state.copyWith(archetype: archetype));

  Future<void> setCustomAccent(Color color) =>
      _commit(state.copyWith(customAccentValue: color.toARGB32()));

  Future<void> clearCustomAccent() =>
      _commit(state.copyWith(clearCustomAccent: true));

  Future<void> setGlassBlur(double value) =>
      _commit(state.copyWith(glassBlur: value));

  Future<void> setGlassOpacity(double value) =>
      _commit(state.copyWith(glassOpacity: value));

  Future<void> setNodeGlowDiffusion(double value) =>
      _commit(state.copyWith(nodeGlowDiffusion: value));

  Future<void> setGlassEffects(GlassEffectPreference value) =>
      _commit(state.copyWith(glassEffects: value));

  Future<void> reset() => _commit(ThemePreferences.defaultPreferences);

  Future<void> replace(ThemePreferences preferences) => _commit(preferences);

  /// Updates the active theme without writing. Pair with [replace] at the end
  /// of a continuous gesture such as a slider drag.
  void preview(ThemePreferences preferences) {
    if (preferences != state) state = preferences;
  }

  Future<void> _commit(ThemePreferences next) async {
    if (next == state) return;
    state = next;
    await _store.save(next);
  }
}

final themeEngineProvider = NotifierProvider<ThemeEngine, ThemePreferences>(
  ThemeEngine.new,
);

ThemeMode themeModeFor(ThemeArchetype archetype) => switch (archetype) {
  ThemeArchetype.dynamicSystem => ThemeMode.system,
  ThemeArchetype.parchment => ThemeMode.light,
  ThemeArchetype.obsidian || ThemeArchetype.cyberMatrix => ThemeMode.dark,
};

VisualThemeTokens visualTokensFor(
  ThemePreferences preferences,
  Brightness platformBrightness,
) => VisualThemeTokens.resolve(preferences, platformBrightness);
