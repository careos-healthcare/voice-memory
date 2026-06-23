/// One preset return ritual option.
class ReturnRitualPreset {
  const ReturnRitualPreset({
    required this.id,
    required this.phrase,
  });

  final String id;
  final String phrase;
}

/// User's saved return ritual — local prefs only, never written to journal.
class ReturnRitualChoice {
  const ReturnRitualChoice({
    required this.presetId,
    this.customPhrase,
  });

  static const customPresetId = 'custom';

  final String presetId;
  final String? customPhrase;

  bool get isValid {
    if (presetId.isEmpty) return false;
    if (presetId == customPresetId) {
      return customPhrase != null && customPhrase!.trim().isNotEmpty;
    }
    return true;
  }

  String resolvePhrase(Iterable<ReturnRitualPreset> presets) {
    if (presetId == customPresetId) {
      return customPhrase?.trim() ?? '';
    }
    for (final preset in presets) {
      if (preset.id == presetId) return preset.phrase;
    }
    return customPhrase?.trim() ?? '';
  }

  Map<String, dynamic> toJson() => {
        'presetId': presetId,
        if (customPhrase != null && customPhrase!.trim().isNotEmpty)
          'customPhrase': customPhrase!.trim(),
      };

  factory ReturnRitualChoice.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ReturnRitualChoice(presetId: '');
    }
    return ReturnRitualChoice(
      presetId: json['presetId'] as String? ?? '',
      customPhrase: json['customPhrase'] as String?,
    );
  }
}
