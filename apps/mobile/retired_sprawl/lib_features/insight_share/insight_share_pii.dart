/// Strips common PII patterns from text destined for share cards or sheets.
abstract final class InsightSharePii {
  InsightSharePii._();

  static const redacted = '[redacted]';

  static final RegExp _email = RegExp(r'[\w.+-]+@[\w.-]+\.\w{2,}', caseSensitive: false);
  static final RegExp _phone = RegExp(
    r'\b(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?){2}\d{4}\b',
  );
  static final RegExp _url = RegExp(r'https?:\/\/\S+', caseSensitive: false);
  static final RegExp _handle = RegExp(r'@[\w.-]+');
  static final RegExp _ssn = RegExp(r'\b\d{3}-\d{2}-\d{4}\b');

  static String strip(String text) {
    var result = text.trim();
    if (result.isEmpty) return '';

    result = result.replaceAll(_email, redacted);
    result = result.replaceAll(_phone, redacted);
    result = result.replaceAll(_url, redacted);
    result = result.replaceAll(_handle, redacted);
    result = result.replaceAll(_ssn, redacted);
    result = result.replaceAll(RegExp(r'(\[redacted\]\s*){2,}'), '$redacted ');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (result == redacted ||
        result.replaceAll(redacted, '').trim().isEmpty) {
      return '';
    }
    return result;
  }

  static List<String> sanitizeLines(Iterable<String> lines) {
    final cleaned = <String>[];
    for (final line in lines) {
      final sanitized = strip(line);
      if (sanitized.isNotEmpty) cleaned.add(sanitized);
    }
    return cleaned;
  }
}