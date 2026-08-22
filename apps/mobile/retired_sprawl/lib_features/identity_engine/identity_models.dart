import 'package:archiveme_mobile/features/theme_tracking/theme_track.dart';

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
      confidence: (json['confidence'] as num?)?.toInt().clamp(0, 100) ?? 0,
      evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
      supportingRecordingIds:
          (json['supportingRecordingIds'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      supportingQuotes: (json['supportingQuotes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
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
          .map(
            (e) => IdentityTrait.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ),
          )
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
      evidenceReflectionCount:
          (json['evidenceReflectionCount'] as num?)?.toInt() ?? 0,
    );
  }
}