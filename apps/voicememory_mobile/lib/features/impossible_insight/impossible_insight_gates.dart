import '../../models/journal_entry.dart';

abstract final class ImpossibleInsightGates {
  static final RegExp _placeholder = RegExp(
    r'^\s*(?:\[draft\]|\[pending\]|pending|transcript pending|processing|'
    r'no transcript|test|placeholder|n/?a|\.\.\.)\s*[.!]?\s*$',
    caseSensitive: false,
  );

  static final RegExp _genericOnly = RegExp(
    r'^\s*(?:i\s+)?(?:felt|feel|am feeling|was)\s+'
    r'(?:bad|good|fine|okay|ok|weird|off|sad|happy|stressed|tired)\s*[.!]?\s*$',
    caseSensitive: false,
  );

  static List<JournalEntry> eligible(List<JournalEntry> entries) {
    final byId = <String, JournalEntry>{};
    for (final entry in entries) {
      final text = entry.transcript.trim();
      if (entry.id.trim().isEmpty ||
          text.length < 18 ||
          _placeholder.hasMatch(text) ||
          _genericOnly.hasMatch(text) ||
          entry.treatAsNew ||
          entry.keepSeparate ||
          entry.isArchived) {
        continue;
      }
      byId[entry.id] = entry;
    }
    final result = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result.length <= 5 ? result : result.sublist(result.length - 5);
  }

  static bool isConcretePhrase(String phrase) {
    final lower = phrase.toLowerCase().trim();
    if (lower.length < 12 || lower.split(RegExp(r'\s+')).length < 3) {
      return false;
    }
    const generic = {
      'i feel like',
      'it feels like',
      'at the moment',
      'the same thing',
      'a lot of work',
      'i think that',
      'and then i',
      'i have been',
    };
    if (generic.any(lower.contains)) return false;
    return RegExp(
      r'\b(?:said|say|agreed|checked|checking|waited|paused|avoided|'
      r'kept|worked|working|stayed|took|taking|asked|asking|replied|'
      r'scrolled|opened|cancelled|started|stopped|chose|choosing)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  static bool hasQuestionForm(String value) =>
      value.trim().endsWith('?') &&
      RegExp(
        r'^(?:what|when|where|which|who|how|does|did|is|was|could)\b',
        caseSensitive: false,
      ).hasMatch(value.trim());
}
