import 'package:flutter/material.dart';

enum ThemeArchetype { obsidian, parchment, cyberMatrix, dynamicSystem }

enum GlassEffectPreference { automatic, full, reduced, off }

@immutable
final class ThemePreferences {
  const ThemePreferences({
    this.schemaVersion = currentSchemaVersion,
    this.archetype = ThemeArchetype.dynamicSystem,
    this.customAccentValue,
    this.glassBlur = 18,
    this.glassOpacity = .86,
    this.nodeGlowDiffusion = .65,
    this.glassEffects = GlassEffectPreference.automatic,
  });

  static const currentSchemaVersion = 1;
  static const defaultPreferences = ThemePreferences();

  final int schemaVersion;
  final ThemeArchetype archetype;
  final int? customAccentValue;
  final double glassBlur;
  final double glassOpacity;
  final double nodeGlowDiffusion;
  final GlassEffectPreference glassEffects;

  Color? get customAccent =>
      customAccentValue == null ? null : Color(customAccentValue!);

  ThemePreferences copyWith({
    ThemeArchetype? archetype,
    int? customAccentValue,
    bool clearCustomAccent = false,
    double? glassBlur,
    double? glassOpacity,
    double? nodeGlowDiffusion,
    GlassEffectPreference? glassEffects,
  }) => ThemePreferences(
    archetype: archetype ?? this.archetype,
    customAccentValue: clearCustomAccent
        ? null
        : customAccentValue ?? this.customAccentValue,
    glassBlur: _blur(glassBlur ?? this.glassBlur),
    glassOpacity: _opacity(glassOpacity ?? this.glassOpacity),
    nodeGlowDiffusion: _glow(nodeGlowDiffusion ?? this.nodeGlowDiffusion),
    glassEffects: glassEffects ?? this.glassEffects,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'archetype': archetype.name,
    if (customAccentValue != null) 'customAccentValue': customAccentValue,
    'glassBlur': glassBlur,
    'glassOpacity': glassOpacity,
    'nodeGlowDiffusion': nodeGlowDiffusion,
    'glassEffects': glassEffects.name,
  };

  factory ThemePreferences.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version < 1 || version > currentSchemaVersion) {
      return defaultPreferences;
    }
    return ThemePreferences(
      archetype: _enumByName(
        ThemeArchetype.values,
        json['archetype'],
        ThemeArchetype.dynamicSystem,
      ),
      customAccentValue: _validColor(json['customAccentValue']),
      glassBlur: _blur((json['glassBlur'] as num?)?.toDouble() ?? 18),
      glassOpacity: _opacity((json['glassOpacity'] as num?)?.toDouble() ?? .86),
      nodeGlowDiffusion: _glow(
        (json['nodeGlowDiffusion'] as num?)?.toDouble() ?? .65,
      ),
      glassEffects: _enumByName(
        GlassEffectPreference.values,
        json['glassEffects'],
        GlassEffectPreference.automatic,
      ),
    );
  }

  static double _blur(double value) => value.clamp(0, 30);
  static double _opacity(double value) => value.clamp(.45, 1);
  static double _glow(double value) => value.clamp(0, 1.5);

  static int? _validColor(Object? value) {
    if (value is! num) return null;
    final color = value.toInt();
    return color >= 0 && color <= 0xffffffff ? color : null;
  }

  static T _enumByName<T extends Enum>(
    Iterable<T> values,
    Object? raw,
    T fallback,
  ) {
    if (raw is! String) return fallback;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is ThemePreferences &&
      other.archetype == archetype &&
      other.customAccentValue == customAccentValue &&
      other.glassBlur == glassBlur &&
      other.glassOpacity == glassOpacity &&
      other.nodeGlowDiffusion == nodeGlowDiffusion &&
      other.glassEffects == glassEffects;

  @override
  int get hashCode => Object.hash(
    archetype,
    customAccentValue,
    glassBlur,
    glassOpacity,
    nodeGlowDiffusion,
    glassEffects,
  );
}
