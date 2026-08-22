/// A routine moment a check-in can be attached to, so tomorrow's check is
/// easier to remember. This is purely a planning label — it does not schedule
/// any real reminder.
enum RoutineAnchorType {
  morning,
  afterWork,
  evening,
  beforeSleep,
  afterHardMoment,
  custom,
}

extension RoutineAnchorTypeIds on RoutineAnchorType {
  String get id => name;

  /// Default consumer-facing label for the anchor type.
  String get label {
    switch (this) {
      case RoutineAnchorType.morning:
        return 'Morning';
      case RoutineAnchorType.afterWork:
        return 'After work';
      case RoutineAnchorType.evening:
        return 'Evening';
      case RoutineAnchorType.beforeSleep:
        return 'Before sleep';
      case RoutineAnchorType.afterHardMoment:
        return 'After a hard moment';
      case RoutineAnchorType.custom:
        return 'Custom';
    }
  }
}

RoutineAnchorType routineAnchorTypeFromId(String? id) {
  for (final t in RoutineAnchorType.values) {
    if (t.id == id) return t;
  }
  return RoutineAnchorType.evening;
}

/// One chosen routine anchor for a check-in.
class RoutineAnchor {
  const RoutineAnchor({required this.type, this.customLabel});

  final RoutineAnchorType type;

  /// User-entered label when [type] is [RoutineAnchorType.custom].
  final String? customLabel;

  /// The label to show the user, e.g. "Evening" or a custom moment.
  String get displayLabel {
    if (type == RoutineAnchorType.custom) {
      final custom = (customLabel ?? '').trim();
      return custom.isNotEmpty ? custom : 'Custom';
    }
    return type.label;
  }

  Map<String, dynamic> toJson() => {
    'type': type.id,
    if (customLabel != null) 'customLabel': customLabel,
  };

  static RoutineAnchor? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final type = map['type'] as String?;
    if (type == null || type.isEmpty) return null;
    return RoutineAnchor(
      type: routineAnchorTypeFromId(type),
      customLabel: map['customLabel'] as String?,
    );
  }
}