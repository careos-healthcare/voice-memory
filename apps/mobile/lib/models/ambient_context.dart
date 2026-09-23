import 'package:meta/meta.dart';

/// Surroundings captured when an entry is saved.
///
/// Stored as structured JSON on the entry payload. Missing fields mean that
/// source was unavailable or the person declined permission.
@immutable
class AmbientContext {
  const AmbientContext({
    this.locality,
    this.weatherLabel,
    this.weatherGlyph = '⛅',
    this.stepCount,
    this.calendarTitle,
    this.capturedAt,
  });

  const AmbientContext.empty()
    : locality = null,
      weatherLabel = null,
      weatherGlyph = '⛅',
      stepCount = null,
      calendarTitle = null,
      capturedAt = null;

  factory AmbientContext.fromJson(Map<String, dynamic> json) {
    final steps = json['stepCount'];
    return AmbientContext(
      locality: _string(json['locality']),
      weatherLabel: _string(json['weatherLabel']),
      weatherGlyph: _string(json['weatherGlyph']) ?? '⛅',
      stepCount: steps is num ? steps.round() : int.tryParse('$steps'),
      calendarTitle: _string(json['calendarTitle']),
      capturedAt: DateTime.tryParse(_string(json['capturedAt']) ?? ''),
    );
  }

  final String? locality;
  final String? weatherLabel;
  final String weatherGlyph;
  final int? stepCount;
  final String? calendarTitle;
  final DateTime? capturedAt;

  bool get isEmpty =>
      (locality == null || locality!.trim().isEmpty) &&
      (weatherLabel == null || weatherLabel!.trim().isEmpty) &&
      stepCount == null &&
      (calendarTitle == null || calendarTitle!.trim().isEmpty);

  Map<String, dynamic> toJson() => {
    if (locality != null && locality!.trim().isNotEmpty) 'locality': locality,
    if (weatherLabel != null && weatherLabel!.trim().isNotEmpty)
      'weatherLabel': weatherLabel,
    if (weatherLabel != null && weatherLabel!.trim().isNotEmpty)
      'weatherGlyph': weatherGlyph,
    if (stepCount != null) 'stepCount': stepCount,
    if (calendarTitle != null && calendarTitle!.trim().isNotEmpty)
      'calendarTitle': calendarTitle,
    if (capturedAt != null) 'capturedAt': capturedAt!.toUtc().toIso8601String(),
  };

  /// One line for the entry card, omitting anything we could not read.
  String? get pillText {
    final parts = <String>[
      if (locality != null && locality!.trim().isNotEmpty) '📍 ${locality!.trim()}',
      if (weatherLabel != null && weatherLabel!.trim().isNotEmpty)
        '$weatherGlyph ${weatherLabel!.trim()}',
      if (stepCount != null) '🚶 ${_formatSteps(stepCount!)} steps',
      if (calendarTitle != null && calendarTitle!.trim().isNotEmpty)
        '📅 ${calendarTitle!.trim()}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  @override
  bool operator ==(Object other) =>
      other is AmbientContext &&
      other.locality == locality &&
      other.weatherLabel == weatherLabel &&
      other.weatherGlyph == weatherGlyph &&
      other.stepCount == stepCount &&
      other.calendarTitle == calendarTitle &&
      other.capturedAt == capturedAt;

  @override
  int get hashCode => Object.hash(
    locality,
    weatherLabel,
    weatherGlyph,
    stepCount,
    calendarTitle,
    capturedAt,
  );
}

String? _string(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatSteps(int count) {
  final digits = count.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return count < 0 ? '-$buffer' : buffer.toString();
}
