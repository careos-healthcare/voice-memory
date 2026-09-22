/// One journal passage the people extractor can read.
class RelationshipSource {
  const RelationshipSource({
    required this.entryId,
    required this.createdAt,
    required this.text,
  });

  final String entryId;
  final DateTime createdAt;
  final String text;
}

/// A person name returned by an optional local model.
class ExtractedMention {
  const ExtractedMention({required this.name, required this.relationship});

  final String name;
  final String relationship;
}

/// Tone of one mention, from -1 (strained) to 1 (warm).
class SentimentPoint {
  const SentimentPoint({required this.at, required this.score});

  final DateTime at;
  final double score;
}

/// Someone who shows up in saved entries, with the moments that mention them.
class PersonRelationship {
  const PersonRelationship({
    required this.name,
    required this.relationship,
    required this.entryIds,
    required this.lastContact,
    required this.sentiment,
    required this.trend,
  });

  final String name;
  final String relationship;
  final List<String> entryIds;
  final DateTime lastContact;
  final double sentiment;
  final List<SentimentPoint> trend;
}

typedef RelationshipMentionReader =
    Future<List<ExtractedMention>> Function(String text);

/// Finds people and relationship tags in entry text.
///
/// A local scan always runs. [llm] can add names the scan missed. A failure
/// there leaves the local names in place.
class RelationshipExtractor {
  const RelationshipExtractor({this.llm});

  final RelationshipMentionReader? llm;

  Future<List<PersonRelationship>> extract(
    List<RelationshipSource> sources,
  ) async {
    final grouped = <String, _Accum>{};
    for (final source in sources) {
      final mentions = await _mentionsFor(source.text);
      if (mentions.isEmpty) continue;
      final sentences = _sentences(source.text);
      for (final mention in mentions) {
        final key = mention.name.toLowerCase();
        final accum = grouped.putIfAbsent(
          key,
          () => _Accum(mention.name, mention.relationship),
        );
        if (accum.relationship == 'mentioned' &&
            mention.relationship != 'mentioned') {
          accum.relationship = mention.relationship;
        }
        accum.entryIds.add(source.entryId);
        if (source.createdAt.isAfter(accum.lastContact)) {
          accum.lastContact = source.createdAt;
        }
        final score = _sentiment(sentences, mention.name);
        accum.scores.add(score);
        accum.trend.add(SentimentPoint(at: source.createdAt, score: score));
      }
    }
    final people = [
      for (final accum in grouped.values) accum.toPerson(),
    ]..sort((a, b) => b.lastContact.compareTo(a.lastContact));
    return people;
  }

  Future<List<ExtractedMention>> _mentionsFor(String text) async {
    final local = _localMentions(text);
    final reader = llm;
    if (reader == null) return local;
    try {
      final extra = await reader(text);
      return _merge(local, extra);
    } on Object {
      return local;
    }
  }
}

class _Accum {
  _Accum(this.name, this.relationship) : lastContact = DateTime.fromMillisecondsSinceEpoch(0);

  final String name;
  String relationship;
  final entryIds = <String>{};
  DateTime lastContact;
  final scores = <double>[];
  final trend = <SentimentPoint>[];

  PersonRelationship toPerson() {
    final mean = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    final ordered = [...trend]..sort((a, b) => a.at.compareTo(b.at));
    return PersonRelationship(
      name: name,
      relationship: relationship,
      entryIds: entryIds.toList(),
      lastContact: lastContact,
      sentiment: mean.clamp(-1, 1).toDouble(),
      trend: ordered,
    );
  }
}

const _roles = <String, String>{
  'mom': 'family',
  'mother': 'family',
  'dad': 'family',
  'father': 'family',
  'sister': 'family',
  'brother': 'family',
  'son': 'family',
  'daughter': 'family',
  'partner': 'partner',
  'wife': 'partner',
  'husband': 'partner',
  'girlfriend': 'partner',
  'boyfriend': 'partner',
  'friend': 'friend',
  'boss': 'work',
  'colleague': 'work',
  'coworker': 'work',
};

const _positive = {
  'glad',
  'grateful',
  'gratitude',
  'love',
  'loved',
  'warm',
  'happy',
  'close',
  'steady',
  'kind',
  'joy',
  'thank',
  'thanked',
  'thanks',
};

const _negative = {
  'angry',
  'hurt',
  'distant',
  'frustrated',
  'lonely',
  'tense',
  'burnt',
  'sad',
  'missed',
  'upset',
  'worried',
};

const _skipNames = {
  'Today',
  'Yesterday',
  'Tomorrow',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
  'The',
  'And',
  'But',
  'This',
  'That',
  'When',
  'After',
  'Before',
  'With',
};

final _rolePattern = RegExp(
  r'\b(?:my|our)\s+(mom|mother|dad|father|sister|brother|son|daughter|partner|wife|husband|girlfriend|boyfriend|friend|boss|colleague|coworker)\b(?:\s+([A-Z][a-z]+))?',
);

final _namePattern = RegExp(r'\b([A-Z][a-z]{2,})\b');

List<ExtractedMention> _localMentions(String text) {
  final found = <String, ExtractedMention>{};
  for (final match in _rolePattern.allMatches(text)) {
    final role = match.group(1)!.toLowerCase();
    final named = match.group(2);
    final label = named ?? _title(role);
    found[label.toLowerCase()] = ExtractedMention(
      name: label,
      relationship: _roles[role] ?? 'mentioned',
    );
  }
  for (final match in _namePattern.allMatches(text)) {
    final name = match.group(1)!;
    if (_skipNames.contains(name)) continue;
    found.putIfAbsent(name.toLowerCase(), () {
      return ExtractedMention(
        name: name,
        relationship: _roles[name.toLowerCase()] ?? 'mentioned',
      );
    });
  }
  return found.values.toList();
}

List<ExtractedMention> _merge(
  List<ExtractedMention> local,
  List<ExtractedMention> extra,
) {
  final found = {for (final item in local) item.name.toLowerCase(): item};
  for (final item in extra) {
    final name = item.name.trim();
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    final existing = found[key];
    if (existing == null ||
        (existing.relationship == 'mentioned' &&
            item.relationship != 'mentioned')) {
      found[key] = ExtractedMention(
        name: existing?.name ?? _title(name),
        relationship: item.relationship,
      );
    }
  }
  return found.values.toList();
}

List<String> _sentences(String text) {
  final parts = text
      .split(RegExp(r'(?<=[.!?])\s+|\n+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);
  return parts.toList();
}

double _sentiment(List<String> sentences, String name) {
  final needle = name.toLowerCase();
  final relevant = sentences.where(
    (sentence) => sentence.toLowerCase().contains(needle),
  );
  final scores = [for (final sentence in relevant) _scoreSentence(sentence)];
  if (scores.isEmpty) return 0;
  final mean = scores.reduce((a, b) => a + b) / scores.length;
  return mean.clamp(-1, 1).toDouble();
}

double _scoreSentence(String sentence) {
  final tokens = sentence.toLowerCase().split(RegExp('[^a-z]+'));
  var score = 0;
  var hits = 0;
  for (final token in tokens) {
    if (_positive.contains(token)) {
      score += 1;
      hits += 1;
    } else if (_negative.contains(token)) {
      score -= 1;
      hits += 1;
    }
  }
  if (hits == 0) return 0;
  return score / hits;
}

String _title(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}
