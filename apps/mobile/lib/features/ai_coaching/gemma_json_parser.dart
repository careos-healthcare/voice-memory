import 'dart:convert';

/// Turns a Gemma reply into a JSON value.
///
/// Strips markdown fences, surrounding prose, and trailing commas so
/// `jsonDecode` does not throw on a chatty model reply.
String cleanGemmaJson(String raw) {
  var text = raw.trim();
  final fenced = RegExp(
    r'```(?:json)?\s*([\s\S]*?)```',
    caseSensitive: false,
  ).firstMatch(text);
  if (fenced != null) {
    text = fenced.group(1)!.trim();
  } else {
    text = text.replaceFirst(
      RegExp(r'^```(?:json)?\s*', caseSensitive: false),
      '',
    );
    text = text.replaceFirst(RegExp(r'\s*```\s*$'), '');
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    text = text.substring(start, end + 1);
  }
  final trailingComma = RegExp(r',\s*([}\]])');
  var previous = '';
  while (previous != text) {
    previous = text;
    text = text.replaceAllMapped(trailingComma, (match) => match[1]!);
  }
  return text.trim();
}

/// Decodes [raw] after [cleanGemmaJson]. Returns null when the text is not JSON.
Object? decodeGemmaJson(String raw) {
  final cleaned = cleanGemmaJson(raw);
  if (cleaned.isEmpty || !cleaned.startsWith('{')) return null;
  try {
    return jsonDecode(cleaned);
  } on FormatException {
    return null;
  }
}
