/// A note the participant typed, held on their own device.
///
/// This is the only free text the mode stores anywhere. It is deliberately the
/// sole occupant of this file: `study_export.dart` does not import it, so the
/// export builder has no expression that could reach a note even by mistake.
/// The participant reads their notes back themselves and decides what to pass
/// on.
final class StudyPrivateNote {
  const StudyPrivateNote({
    required this.text,
    required this.writtenAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const currentSchemaVersion = 1;
  static const maxLength = 500;

  final String text;
  final DateTime writtenAt;
  final int schemaVersion;

  static String? normalize(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }

  Map<String, Object?> toJson() => {
    'text': text,
    'writtenAt': writtenAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  static StudyPrivateNote? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final text = normalize(json['text']?.toString());
    final writtenAt = DateTime.tryParse(json['writtenAt']?.toString() ?? '');
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();
    if (text == null ||
        writtenAt == null ||
        schemaVersion != currentSchemaVersion) {
      return null;
    }
    return StudyPrivateNote(
      text: text,
      writtenAt: writtenAt.toUtc(),
      schemaVersion: schemaVersion!,
    );
  }
}
