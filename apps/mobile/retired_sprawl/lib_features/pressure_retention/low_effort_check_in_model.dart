import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_option.dart' show PressureCheckInOption;

/// The four one-tap answers for the low-effort check-in. Continuity signals
/// about the tracked thread — not moods, not scores, not diagnoses.
enum LowEffortCheckInOption {
  returned(id: 'returned', label: 'It returned'),
  faded(id: 'faded', label: 'It faded'),
  changed(id: 'changed', label: 'It changed'),
  notSure(id: 'not_sure', label: 'Not sure');

  const LowEffortCheckInOption({required this.id, required this.label});

  /// Stable id, safe to persist.
  final String id;

  /// Consumer-facing button label.
  final String label;

  /// The marker option id stored on the check-in record. Resolves to no
  /// [PressureCheckInOption], so option-based engines ignore these records.
  String get recordOptionId => '${LowEffortCheckIn.optionIdPrefix}$id';
}

/// Copy for the one-tap fallback below One Small Recording: a tiny archive
/// contribution for days when a full recording feels like too much.
/// Always optional and secondary — never homework, never a streak.
class LowEffortCheckIn {
  static const String title = 'Too much to record?';
  static const String subtitle = 'Tap one thing instead.';

  /// Shown only after the entry was genuinely persisted.
  static const String confirmation = 'Saved. That is enough for today.';

  /// Prefix for the marker option ids stored on low-effort records.
  static const String optionIdPrefix = 'low_effort_';
}