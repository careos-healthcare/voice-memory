import '../../models/journal_entry.dart';

/// Reflection-backed statement used for contradiction and belief-shift analysis.
class ArchivedStatement {
  ArchivedStatement({
    required this.entryId,
    required this.at,
    required this.text,
    required this.themes,
    required this.keywords,
    required this.negativeScore,
    required this.positiveScore,
    required this.softNegativeScore,
  });

  final String entryId;
  final DateTime at;
  final String text;
  final Set<String> themes;
  final Set<String> keywords;
  final int negativeScore;
  final int positiveScore;
  final int softNegativeScore;

  bool get isStrongNegative => negativeScore >= 2 || _hasStrongNegativePhrase(text);
  bool get isNegative =>
      isStrongNegative || negativeScore > positiveScore && negativeScore > 0;
  bool get isSoftNegative =>
      softNegativeScore > 0 && !isPositive && positiveScore <= negativeScore;
  bool get isPositive => positiveScore > negativeScore && positiveScore > 0;

  factory ArchivedStatement.from(JournalEntry entry, String text) {
    final lower = text.toLowerCase();
    final themes = <String>{
      ...entry.reflection.recurringThemes.map((t) => t.trim().toLowerCase()),
      ...extractTopicKeywords(lower),
    }..removeWhere((t) => t.isEmpty);

    return ArchivedStatement(
      entryId: entry.id,
      at: entry.createdAt,
      text: text,
      themes: themes,
      keywords: significantWords(lower),
      negativeScore: scoreMarkers(lower, negativeMarkers),
      positiveScore: scoreMarkers(lower, positiveMarkers),
      softNegativeScore: scoreMarkers(lower, softNegativeMarkers),
    );
  }

  bool sharesTopicWith(ArchivedStatement other) {
    if (themes.intersection(other.themes).isNotEmpty) return true;
    return keywords.intersection(other.keywords).length >= 2;
  }

  String? primaryTopic() {
    const priority = [
      'networking',
      'career',
      'confidence',
      'approval',
      'relationship',
      'money',
      'health',
      'work',
      'leadership',
      'burnout',
    ];
    for (final t in priority) {
      if (themes.contains(t) || keywords.contains(t)) return t;
    }
    if (themes.isNotEmpty) return themes.first;
    return null;
  }
}

List<ArchivedStatement> archivedStatementsFromEntries(List<JournalEntry> entries) {
  final statements = <ArchivedStatement>[];
  for (final entry in entries) {
    for (final text in archiveStatementTexts(entry)) {
      statements.add(ArchivedStatement.from(entry, text));
    }
  }
  statements.sort((a, b) => a.at.compareTo(b.at));
  return statements;
}

List<String> archiveStatementTexts(JournalEntry entry) {
  final out = <String>[];
  void add(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.length >= 12) {
      out.add(t.length <= 220 ? t : '${t.substring(0, 220).trim()}…');
    }
  }

  add(entry.reflection.exactLanguagePattern);
  add(entry.reflection.concreteObservation);
  final tension = entry.reflection.tensionOrContradiction;
  if (tension != null) add(tension);

  final transcript = entry.transcript.trim();
  if (transcript.isNotEmpty) {
    final line = transcript.split('\n').first.trim();
    add(line);
  }

  return out.toSet().toList();
}

Set<String> significantWords(String lower) {
  return lower
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length >= 5 && !archiveStopWords.contains(w))
      .toSet();
}

Set<String> extractTopicKeywords(String lower) {
  const topics = [
    'networking',
    'career',
    'work',
    'family',
    'money',
    'health',
    'relationship',
    'approval',
    'judgment',
    'confidence',
    'leadership',
    'burnout',
  ];
  return topics.where(lower.contains).toSet();
}

int scoreMarkers(String lower, List<String> markers) {
  var score = 0;
  for (final m in markers) {
    if (lower.contains(m)) score++;
  }
  return score;
}

bool hasReversalPhrase(String earlier, String later) {
  final e = earlier.toLowerCase();
  final l = later.toLowerCase();
  const pairs = [
    ('hate', 'love'),
    ('hate', 'enjoy'),
    ('hate', 'changed my'),
    ('avoid', 'embrace'),
    ('never', 'always'),
    ('worst', 'best'),
    ("can't stand", 'changed my'),
    ('against', 'for'),
    ('uncomfortable', 'changed my'),
    ('uncomfortable', 'helped'),
  ];
  for (final p in pairs) {
    if (e.contains(p.$1) && l.contains(p.$2)) return true;
    if (e.contains(p.$2) && l.contains(p.$1)) return true;
  }
  return false;
}

bool _hasStrongNegativePhrase(String text) {
  final lower = text.toLowerCase();
  return const ['hate', "can't stand", 'cannot stand', 'despise'].any(lower.contains);
}

const negativeMarkers = [
  'hate',
  'despise',
  'avoid',
  'never',
  "can't stand",
  'cannot stand',
  'worst',
  'failed',
  'against',
  'resent',
  'drain',
  'anxious',
  'fear',
];

const softNegativeMarkers = [
  'uncomfortable',
  'awkward',
  'reluctant',
  'hard to',
  'difficult',
  'not sure',
  'uncertain',
  'struggle',
  'tension',
];

const positiveMarkers = [
  'love',
  'enjoy',
  'embrace',
  'always',
  'best',
  'grateful',
  'helped',
  'changed my career',
  'changed my life',
  'growth',
  'trust',
  'proud',
  'excited',
  'more confident',
  'confident',
];

const archiveStopWords = {
  'about',
  'after',
  'again',
  'being',
  'could',
  'really',
  'still',
  'their',
  'there',
  'these',
  'think',
  'those',
  'through',
  'under',
  'until',
  'while',
  'would',
  'your',
};
