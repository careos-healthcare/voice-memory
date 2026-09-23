import 'dart:convert';

/// Surroundings captured when a recording starts.
class AmbientMetadata {
  const AmbientMetadata({
    this.city,
    this.locality,
    this.latitude,
    this.longitude,
    this.temperatureC,
    this.conditionCode,
    this.stepCount,
    this.movementState,
    this.capturedAt,
  });

  factory AmbientMetadata.fromJson(Map<String, dynamic> json) {
    final location = _map(json['location']);
    final weather = _map(json['weather']);
    final activity = _map(json['activity']);
    return AmbientMetadata(
      city: _string(location?['city']),
      locality: _string(location?['locality']),
      latitude: _double(location?['latitude']),
      longitude: _double(location?['longitude']),
      temperatureC: _double(weather?['temperature']),
      conditionCode: _int(weather?['conditionCode']),
      stepCount: _int(activity?['stepCount']),
      movementState: _string(activity?['movementState']),
      capturedAt: DateTime.tryParse(_string(json['capturedAt']) ?? ''),
    );
  }

  final String? city;
  final String? locality;
  final double? latitude;
  final double? longitude;
  final double? temperatureC;
  final int? conditionCode;
  final int? stepCount;
  final String? movementState;
  final DateTime? capturedAt;

  bool get isEmpty =>
      placeLabel == null && temperatureC == null && stepCount == null;

  String? get placeLabel {
    final local = locality?.trim();
    if (local != null && local.isNotEmpty) return local;
    final namedCity = city?.trim();
    if (namedCity != null && namedCity.isNotEmpty) return namedCity;
    return null;
  }

  /// Compact line such as "📍 Banstead • 🌤️ 18°C • 🚶 2,400 steps".
  String? get badgeText {
    final parts = <String>[
      if (placeLabel != null) '📍 $placeLabel',
      if (temperatureC != null)
        '${weatherGlyph(conditionCode)} ${temperatureC!.round()}°C',
      if (stepCount != null) '🚶 ${formatStepCount(stepCount!)} steps',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  Map<String, dynamic> toJson() => {
    'location': {
      if (city != null) 'city': city,
      if (locality != null) 'locality': locality,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    },
    'weather': {
      if (temperatureC != null) 'temperature': temperatureC,
      if (conditionCode != null) 'conditionCode': conditionCode,
    },
    'activity': {
      if (stepCount != null) 'stepCount': stepCount,
      if (movementState != null) 'movementState': movementState,
    },
    if (capturedAt != null) 'capturedAt': capturedAt!.toUtc().toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  static AmbientMetadata? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final body = jsonDecode(raw);
      if (body is! Map) return null;
      return AmbientMetadata.fromJson(Map<String, dynamic>.from(body));
    } on Object {
      return null;
    }
  }
}

String weatherGlyph(int? code) {
  if (code == null) return '🌤️';
  if (code == 0) return '☀️';
  if (code <= 3) return '🌤️';
  if (code <= 48) return '🌫️';
  if (code <= 67 || (code >= 80 && code <= 82)) return '🌧️';
  if (code <= 77 || (code >= 85 && code <= 86)) return '🌨️';
  return '⛈️';
}

String formatStepCount(int count) {
  final digits = count.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return count < 0 ? '-$buffer' : buffer.toString();
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _string(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _int(Object? value) {
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}
