/// A reflection line prepared for a share card, with identifying details removed.
abstract final class ThoughtCardText {
  ThoughtCardText._();

  static final _email = RegExp(r'\S+@\S+\.\S+');
  static final _url = RegExp(r'https?://\S+');
  static final _handle = RegExp(r'@\w+');
  static final _phone = RegExp(r'\+?\d[\d\s().-]{7,}\d');
  static final _namedPerson = RegExp(
    r'\b(with|from|to|dear|for)\s+[A-Z][a-z]+\b',
  );
  static final _space = RegExp(r'\s+');

  /// Returns the quote or summary safe to paint on a shared card.
  static String anonymize(String raw) {
    var text = raw.trim();
    text = text.replaceAll(_email, '');
    text = text.replaceAll(_url, '');
    text = text.replaceAll(_handle, '');
    text = text.replaceAll(_phone, '');
    text = text.replaceAll(_namedPerson, '');
    text = text.replaceAll(_space, ' ').trim();
    if (text.length > 180) {
      text = text.substring(0, 180).trim();
    }
    return text;
  }
}
