/// Typed JSON helpers for API and domain model deserialization.
///
/// Avoids brittle `as` casts on polymorphic wire payloads when
/// [strict-casts](https://dart.dev/tools/analysis#language) is enabled.
abstract final class JsonConverters {
  static String string(Object? value, {String field = 'value'}) {
    if (value is String) {
      return value;
    }
    if (value == null) {
      throw FormatException('Missing required string: $field');
    }
    return value.toString();
  }

  static String stringOrEmpty(Object? value) {
    if (value is String) {
      return value;
    }
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  static String? nullableString(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }

  static int intValue(Object? value, {String field = 'value'}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Expected int for $field, got ${value.runtimeType}');
  }

  static int intOrZero(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  static int? nullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static bool boolValue(Object? value, {String field = 'value'}) {
    if (value is bool) {
      return value;
    }
    throw FormatException('Expected bool for $field, got ${value.runtimeType}');
  }

  static bool? nullableBool(Object? value) => value is bool ? value : null;

  static bool boolOrFalse(Object? value) => value is bool ? value : false;

  static Map<String, dynamic> requiredStringMap(
    Object? value, {
    String field = 'value',
  }) {
    if (value == null) {
      throw FormatException('Missing required JSON object: $field');
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw FormatException(
      'Expected JSON object for $field, got ${value.runtimeType}',
    );
  }

  static Map<String, dynamic>? nullableStringMap(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static Map<String, dynamic> stringMapOrEmpty(Object? value) =>
      nullableStringMap(value) ?? const {};

  static List<String> stringList(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      return const [];
    }
    return value
        .map((entry) => entry is String ? entry : entry?.toString() ?? '')
        .toList();
  }

  static List<T> objectList<T>(
    Object? value,
    T Function(Map<String, dynamic> json) parse, {
    String field = 'value',
  }) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      return const [];
    }
    return value
        .map(
          (entry) => parse(requiredStringMap(entry, field: field)),
        )
        .toList();
  }

  static T requiredObject<T>(
    Object? value,
    T Function(Map<String, dynamic> json) parse, {
    String field = 'value',
  }) =>
      parse(requiredStringMap(value, field: field));

  static T? nullableObject<T>(
    Object? value,
    T Function(Map<String, dynamic> json) parse,
  ) {
    final map = nullableStringMap(value);
    return map == null ? null : parse(map);
  }
}
