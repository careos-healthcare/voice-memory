/// A question the app spoke during a recording.
///
/// Kept off [JournalEntry.transcript] so the saved words stay the person's.
class AppSpokenQuestion {
  const AppSpokenQuestion({
    required this.text,
    required this.askedAt,
    required this.afterUserChars,
  });

  final String text;
  final DateTime askedAt;

  /// How many characters of the user transcript came before this question.
  final int afterUserChars;

  Map<String, dynamic> toJson() => {
    'text': text,
    'askedAt': askedAt.toUtc().toIso8601String(),
    'afterUserChars': afterUserChars,
  };

  static List<AppSpokenQuestion> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    final questions = <AppSpokenQuestion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final text = item['text']?.toString().trim() ?? '';
      final askedAt = DateTime.tryParse(item['askedAt']?.toString() ?? '');
      final after = item['afterUserChars'];
      if (text.isEmpty || askedAt == null || after is! num) continue;
      questions.add(
        AppSpokenQuestion(
          text: text,
          askedAt: askedAt.toUtc(),
          afterUserChars: after.toInt(),
        ),
      );
    }
    return List.unmodifiable(questions);
  }

  @override
  bool operator ==(Object other) =>
      other is AppSpokenQuestion &&
      other.text == text &&
      other.askedAt == askedAt &&
      other.afterUserChars == afterUserChars;

  @override
  int get hashCode => Object.hash(text, askedAt, afterUserChars);
}
