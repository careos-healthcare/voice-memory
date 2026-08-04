/// The optional ten-second check a reader may attach to one saved moment.
///
/// Markers are secondary evidence. The saved words are the record; a marker
/// only ever adds a comparable reading the words did not already give, and it
/// is never required to save a moment. There is no scoring, no streak and no
/// mood label derived from them.
library;

enum MarkerStrength { low, medium, high }

enum MarkerAction { avoided, continued, stopped, askedForHelp, other }

enum MarkerResolution { unresolved, partlyResolved, resolved }

extension MarkerStrengthLabel on MarkerStrength {
  String get label => switch (this) {
    MarkerStrength.low => 'Low',
    MarkerStrength.medium => 'Medium',
    MarkerStrength.high => 'High',
  };
}

extension MarkerActionLabel on MarkerAction {
  String get label => switch (this) {
    MarkerAction.avoided => 'Avoided',
    MarkerAction.continued => 'Continued',
    MarkerAction.stopped => 'Stopped',
    MarkerAction.askedForHelp => 'Asked for help',
    MarkerAction.other => 'Other',
  };
}

extension MarkerResolutionLabel on MarkerResolution {
  String get label => switch (this) {
    MarkerResolution.unresolved => 'Unresolved',
    MarkerResolution.partlyResolved => 'Partly resolved',
    MarkerResolution.resolved => 'Resolved',
  };
}

/// The three questions of the check, in the order they are asked.
abstract final class StructuredCheckPrompts {
  static const strength = 'How strong was this?';
  static const action = 'What did you do?';
  static const resolution = 'How did it end?';
}

/// One moment's markers. Every field is independently optional, so a reader may
/// answer one question, all three, or none.
class StructuredMarkers {
  const StructuredMarkers({
    required this.entryId,
    this.strength,
    this.action,
    this.resolution,
    this.updatedAt,
  });

  final String entryId;
  final MarkerStrength? strength;
  final MarkerAction? action;
  final MarkerResolution? resolution;
  final DateTime? updatedAt;

  bool get isEmpty => strength == null && action == null && resolution == null;

  bool get isNotEmpty => !isEmpty;

  /// Copies with explicit clearing, so removing one answer is expressible.
  StructuredMarkers copyWith({
    MarkerStrength? strength,
    MarkerAction? action,
    MarkerResolution? resolution,
    DateTime? updatedAt,
    bool clearStrength = false,
    bool clearAction = false,
    bool clearResolution = false,
  }) => StructuredMarkers(
    entryId: entryId,
    strength: clearStrength ? null : (strength ?? this.strength),
    action: clearAction ? null : (action ?? this.action),
    resolution: clearResolution ? null : (resolution ?? this.resolution),
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Drops every answer while keeping the moment's identity.
  StructuredMarkers cleared({DateTime? updatedAt}) => StructuredMarkers(
    entryId: entryId,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Reader-facing summary lines. Only answered questions appear.
  List<String> get summaryLines => [
    if (strength != null)
      '${StructuredCheckPrompts.strength} ${strength!.label}',
    if (action != null) '${StructuredCheckPrompts.action} ${action!.label}',
    if (resolution != null)
      '${StructuredCheckPrompts.resolution} ${resolution!.label}',
  ];

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    if (strength != null) 'strength': strength!.name,
    if (action != null) 'action': action!.name,
    if (resolution != null) 'resolution': resolution!.name,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  static StructuredMarkers? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final entryId = json['entryId']?.toString() ?? '';
    if (entryId.isEmpty) return null;
    return StructuredMarkers(
      entryId: entryId,
      strength: _enumOf(MarkerStrength.values, json['strength']),
      action: _enumOf(MarkerAction.values, json['action']),
      resolution: _enumOf(MarkerResolution.values, json['resolution']),
      updatedAt: DateTime.tryParse(
        json['updatedAt']?.toString() ?? '',
      )?.toUtc(),
    );
  }

  static T? _enumOf<T extends Enum>(List<T> values, Object? raw) =>
      values.where((value) => value.name == raw).firstOrNull;
}
