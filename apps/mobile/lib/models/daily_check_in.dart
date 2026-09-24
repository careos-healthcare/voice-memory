/// One local daily check-in row from `daily_checkins`.
final class DailyCheckIn {
  DailyCheckIn({
    required this.id,
    required this.dateString,
    required this.moodScore,
    required this.energyLevel,
    this.habitsJson = '[]',
  }) {
    if (!datePattern.hasMatch(dateString)) {
      throw ArgumentError.value(
        dateString,
        'dateString',
        'expected YYYY-MM-DD',
      );
    }
    _requireScore(moodScore, 'moodScore');
    _requireScore(energyLevel, 'energyLevel');
  }

  static final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  final String id;
  final String dateString;
  final int moodScore;
  final int energyLevel;
  final String habitsJson;

  Map<String, Object?> toRow() => {
    'id': id,
    'date_string': dateString,
    'mood_score': moodScore,
    'energy_level': energyLevel,
    'habits_json': habitsJson,
  };

  static DailyCheckIn fromRow(Map<String, Object?> row) {
    return DailyCheckIn(
      id: row['id'] as String? ?? '',
      dateString: row['date_string'] as String? ?? '',
      moodScore: row['mood_score'] as int? ?? 1,
      energyLevel: row['energy_level'] as int? ?? 1,
      habitsJson: row['habits_json'] as String? ?? '[]',
    );
  }

  static void _requireScore(int score, String name) {
    if (score < 1 || score > 5) {
      throw ArgumentError.value(score, name, 'expected an integer from 1 to 5');
    }
  }
}
