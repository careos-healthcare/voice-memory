/// Builds safe FTS5 `MATCH` expressions from user-entered search text.
abstract final class SqliteFtsQuery {
  SqliteFtsQuery._();

  /// Tokenizes [raw] into a prefix-friendly OR query (`"token"* OR ...`).
  static String toMatchQuery(String raw) {
    final tokens = raw
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((token) => token.replaceAll(RegExp(r'[^a-z0-9]+'), ''))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return '';
    }
    return tokens.map((token) => '"$token"*').join(' OR ');
  }

  static bool hasMatchTerms(String raw) => toMatchQuery(raw).isNotEmpty;
}
