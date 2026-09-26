/// Tag-frequency pairs drawn from the words a person actually saved.
class ThemeCooccurrence {
  const ThemeCooccurrence({
    required this.left,
    required this.right,
    required this.entryIds,
  });

  final String left;
  final String right;
  final List<String> entryIds;

  String get sentence =>
      "You frequently mention '$left' and '$right' together";
}

abstract final class ThemeFrequency {
  ThemeFrequency._();

  static const _stopWords = {
    'the', 'and', 'that', 'this', 'with', 'from', 'have', 'just', 'been',
    'were', 'was', 'are', 'for', 'you', 'your', 'about', 'into', 'then',
    'they', 'them', 'what', 'when', 'where', 'which', 'while', 'would',
    'could', 'should', 'there', 'their', 'being', 'because',
    'really', 'very', 'like', 'feel', 'felt', 'today', 'yesterday',
  };

  static List<ThemeCooccurrence> analyze(
    List<({String id, String text})> entries,
  ) {
    final pairs = <String, Set<String>>{};
    final labels = <String, (String, String)>{};
    for (final entry in entries) {
      final words = _words(entry.text);
      final unique = words.toSet().toList()..sort();
      for (var i = 0; i < unique.length; i++) {
        for (var j = i + 1; j < unique.length; j++) {
          final key = '${unique[i]}|${unique[j]}';
          pairs.putIfAbsent(key, () => {}).add(entry.id);
          labels[key] = (unique[i], unique[j]);
        }
      }
    }
    final found = [
      for (final entry in pairs.entries)
        if (entry.value.length >= 2)
          ThemeCooccurrence(
            left: labels[entry.key]!.$1,
            right: labels[entry.key]!.$2,
            entryIds: entry.value.toList()..sort(),
          ),
    ]..sort((a, b) => b.entryIds.length.compareTo(a.entryIds.length));
    return found;
  }

  static List<String> _words(String text) {
    return [
      for (final match in RegExp(r"[a-zA-Z']+").allMatches(text.toLowerCase()))
        if (match.group(0)!.length >= 4 && !_stopWords.contains(match.group(0)))
          match.group(0)!,
    ];
  }
}
