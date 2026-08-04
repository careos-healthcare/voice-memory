/// Optional ambient context resolved on-device at the user's request.
///
/// Raw coordinates, calendar identifiers, attendees, and event descriptions are
/// deliberately never retained.
class LocalCaptureContext {
  const LocalCaptureContext({
    required this.capturedAt,
    this.locationLabel,
    this.calendarEventName,
  });

  final DateTime capturedAt;
  final String? locationLabel;
  final String? calendarEventName;

  bool get isEmpty =>
      locationLabel?.trim().isNotEmpty != true &&
      calendarEventName?.trim().isNotEmpty != true;

  Map<String, dynamic> toJson() => {
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    if (locationLabel?.trim().isNotEmpty == true)
      'locationLabel': locationLabel!.trim(),
    if (calendarEventName?.trim().isNotEmpty == true)
      'calendarEventName': calendarEventName!.trim(),
  };

  factory LocalCaptureContext.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LocalCaptureContext(capturedAt: DateTime.now().toUtc());
    }
    return LocalCaptureContext(
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      locationLabel: _safeText(json['locationLabel']),
      calendarEventName: _safeText(json['calendarEventName']),
    );
  }

  static String? _safeText(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= 100 ? trimmed : trimmed.substring(0, 100);
  }
}
