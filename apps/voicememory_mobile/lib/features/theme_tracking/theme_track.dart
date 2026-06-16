/// Canonical archive theme with occurrence and trend metadata.
class ArchiveTheme {
  const ArchiveTheme({
    required this.name,
    required this.frequency,
    required this.trend,
    this.firstSeen,
    this.lastSeen,
  });

  final String name;
  final int frequency;
  final ThemeTrend trend;
  final DateTime? firstSeen;
  final DateTime? lastSeen;

  String get trendLabel => trend.displayLabel;

  String get trendGlyph => trend.glyph;

  Map<String, dynamic> toJson() => {
    'name': name,
    'frequency': frequency,
    'trend': trend.name,
    if (firstSeen != null) 'firstSeen': firstSeen!.toUtc().toIso8601String(),
    if (lastSeen != null) 'lastSeen': lastSeen!.toUtc().toIso8601String(),
  };

  static ArchiveTheme? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = json['name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    return ArchiveTheme(
      name: name,
      frequency: (json['frequency'] as num?)?.toInt() ?? 0,
      trend: ThemeTrend.fromName(json['trend']?.toString()),
      firstSeen: DateTime.tryParse(json['firstSeen']?.toString() ?? ''),
      lastSeen: DateTime.tryParse(json['lastSeen']?.toString() ?? ''),
    );
  }
}

enum ThemeTrend {
  up,
  down,
  stable;

  static ThemeTrend fromName(String? raw) {
    switch (raw) {
      case 'up':
        return ThemeTrend.up;
      case 'down':
        return ThemeTrend.down;
      default:
        return ThemeTrend.stable;
    }
  }

  String get glyph => switch (this) {
    ThemeTrend.up => '↑',
    ThemeTrend.down => '↓',
    ThemeTrend.stable => '→',
  };

  String get displayLabel => switch (this) {
    ThemeTrend.up => 'Rising',
    ThemeTrend.down => 'Falling',
    ThemeTrend.stable => 'Steady',
  };
}

class ThemeTrackingResult {
  const ThemeTrackingResult({required this.topThemes});

  final List<ArchiveTheme> topThemes;

  bool get hasThemes => topThemes.any((t) => t.frequency > 0);
}
