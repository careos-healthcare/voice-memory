import '../ai_engines/models/ai_explainability.dart';
import '../theme_tracking/theme_track.dart';

/// Evidence-backed identity line — never invented without recordings.
class IdentityTrait {
  const IdentityTrait({
    required this.id,
    required this.title,
    required this.confidence,
    required this.evidenceCount,
    required this.supportingRecordingIds,
    required this.supportingQuotes,
    required this.trend,
    this.firstSeen,
    this.lastSeen,
  });

  final String id;
  final String title;
  final int confidence;
  final int evidenceCount;
  final List<String> supportingRecordingIds;
  final List<String> supportingQuotes;
  final ThemeTrend trend;
  final DateTime? firstSeen;
  final DateTime? lastSeen;

  String get trendLabel => '${trend.glyph} ${trend.displayLabel}';

  AiExplainability get explainability => AiExplainability(
    confidence: confidence.clamp(0, 100),
    evidence: supportingQuotes.isEmpty
        ? [AiEvidenceSource(sourceId: id, excerpt: title)]
        : List.generate(
            supportingQuotes.length,
            (index) => AiEvidenceSource(
              sourceId: index < supportingRecordingIds.length
                  ? supportingRecordingIds[index]
                  : id,
              excerpt: supportingQuotes[index],
            ),
          ),
    reasoning: [
      'The theme appeared in $evidenceCount saved moments.',
      'Its current direction is ${trend.displayLabel.toLowerCase()}.',
      'The confidence score is limited by the available evidence.',
    ],
    alternativeExplanation:
        'This may describe a temporary focus in recent recordings rather than '
        'a lasting identity trait.',
    uncertainty:
        'Silence about a theme does not prove that it is absent from your life.',
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'confidence': confidence,
    'evidenceCount': evidenceCount,
    'supportingRecordingIds': supportingRecordingIds,
    'supportingQuotes': supportingQuotes,
    'trend': trend.name,
    if (firstSeen != null) 'firstSeen': firstSeen!.toUtc().toIso8601String(),
    if (lastSeen != null) 'lastSeen': lastSeen!.toUtc().toIso8601String(),
  };

  static IdentityTrait? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final title = json['title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;
    return IdentityTrait(
      id: json['id']?.toString() ?? '',
      title: title,
      confidence: _legacyInt(json['confidence']).clamp(0, 100).toInt(),
      evidenceCount: _legacyInt(json['evidenceCount']),
      supportingRecordingIds: _legacyStringList(json['supportingRecordingIds']),
      supportingQuotes: _legacyStringList(json['supportingQuotes']),
      trend: ThemeTrend.fromName(json['trend']?.toString()),
      firstSeen: DateTime.tryParse(json['firstSeen']?.toString() ?? ''),
      lastSeen: DateTime.tryParse(json['lastSeen']?.toString() ?? ''),
    );
  }
}

class IdentityProfile {
  const IdentityProfile({
    required this.currentTraits,
    required this.emergingTraits,
    required this.decliningTraits,
    required this.lastUpdated,
    required this.hasMinimumArchiveEvidence,
    required this.evidenceReflectionCount,
  });

  final List<IdentityTrait> currentTraits;
  final List<IdentityTrait> emergingTraits;
  final List<IdentityTrait> decliningTraits;
  final DateTime lastUpdated;
  final bool hasMinimumArchiveEvidence;
  final int evidenceReflectionCount;

  bool get hasTraits =>
      currentTraits.isNotEmpty ||
      emergingTraits.isNotEmpty ||
      decliningTraits.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'lastUpdated': lastUpdated.toUtc().toIso8601String(),
    'hasMinimumArchiveEvidence': hasMinimumArchiveEvidence,
    'evidenceReflectionCount': evidenceReflectionCount,
    'currentTraits': currentTraits.map((t) => t.toJson()).toList(),
    'emergingTraits': emergingTraits.map((t) => t.toJson()).toList(),
    'decliningTraits': decliningTraits.map((t) => t.toJson()).toList(),
  };

  static IdentityProfile empty({int evidenceCount = 0}) {
    return IdentityProfile(
      currentTraits: const [],
      emergingTraits: const [],
      decliningTraits: const [],
      lastUpdated: DateTime.now().toUtc(),
      hasMinimumArchiveEvidence: false,
      evidenceReflectionCount: evidenceCount,
    );
  }

  static IdentityProfile fromJson(Map<String, dynamic>? json) {
    if (json == null) return IdentityProfile.empty();
    List<IdentityTrait> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => IdentityTrait.fromJson(Map<String, dynamic>.from(e)))
          .whereType<IdentityTrait>()
          .toList();
    }

    return IdentityProfile(
      currentTraits: parseList(json['currentTraits']),
      emergingTraits: parseList(json['emergingTraits']),
      decliningTraits: parseList(json['decliningTraits']),
      lastUpdated:
          DateTime.tryParse(json['lastUpdated']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      hasMinimumArchiveEvidence: json['hasMinimumArchiveEvidence'] == true,
      evidenceReflectionCount: _legacyInt(json['evidenceReflectionCount']),
    );
  }
}

int _legacyInt(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()) ?? 0,
  _ => 0,
};

List<String> _legacyStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .where((item) => item != null)
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
