/// Clock (`m:ss`) or whole seconds. A calendar timestamp stays unset.
int? audioOffsetSeconds(String timestamp) {
  final clock = RegExp(r'^(\d+):(\d{2})$').firstMatch(timestamp.trim());
  if (clock != null) {
    return int.parse(clock.group(1)!) * 60 + int.parse(clock.group(2)!);
  }
  return int.tryParse(timestamp.trim());
}

class VerbatimCitation {
  const VerbatimCitation({
    required this.text,
    required this.entryId,
    required this.timestamp,
  });

  factory VerbatimCitation.fromJson(Map<String, Object?> json) {
    return VerbatimCitation(
      text: json['text'] as String? ?? '',
      entryId: json['entryId'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  final String text;
  final String entryId;
  final String timestamp;

  Map<String, Object?> toJson() => {
    'text': text,
    'entryId': entryId,
    'timestamp': timestamp,
  };
}

class WeeklyRecap {
  const WeeklyRecap({
    required this.weekKey,
    required this.summary,
    required this.keyThemes,
    required this.emotionalArc,
    required this.verbatimCitations,
  });

  factory WeeklyRecap.fromJson(Map<String, Object?> json) {
    final citations = json['verbatimCitations'];
    return WeeklyRecap(
      weekKey: json['weekKey'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      keyThemes: [
        for (final theme in (json['keyThemes'] as List<Object?>? ?? const []))
          theme.toString(),
      ],
      emotionalArc: json['emotionalArc'] as String? ?? '',
      verbatimCitations: [
        for (final item in (citations is List ? citations : const <Object?>[]))
          if (item is Map)
            VerbatimCitation.fromJson(Map<String, Object?>.from(item)),
      ],
    );
  }

  final String weekKey;
  final String summary;
  final List<String> keyThemes;
  final String emotionalArc;
  final List<VerbatimCitation> verbatimCitations;

  Map<String, Object?> toJson() => {
    'weekKey': weekKey,
    'summary': summary,
    'keyThemes': keyThemes,
    'emotionalArc': emotionalArc,
    'verbatimCitations': verbatimCitations.map((item) => item.toJson()).toList(),
  };
}
