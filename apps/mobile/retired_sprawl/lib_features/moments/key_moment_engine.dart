import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/moments/moment_tag_engine.dart';

/// Builds a single [KeyMoment] from a reflection (and any result context).
///
/// Conservative by design: the original text is preserved exactly, the summary
/// is drawn from the user's own words, and tags only fire on plain keywords. No
/// facts are invented and no claims are made.
KeyMoment buildKeyMoment({
  required String reflectionText,
  required DateTime date,
  String? patternTitle,
  String? resultHint,
  String? nextCheck,
  String? languageCode,
  KeyMomentSource source = KeyMomentSource.reflection,
  String? id,
}) {
  final original = reflectionText;
  final hint = _normalizeHint(resultHint);
  return KeyMoment(
    id: id ?? 'km_${date.microsecondsSinceEpoch}',
    date: date,
    title: _title(patternTitle: patternTitle, hint: hint),
    originalText: original,
    shortSummary: _shortSummary(original),
    patternTitle: (patternTitle != null && patternTitle.trim().isNotEmpty)
        ? patternTitle.trim()
        : null,
    resultHint: hint,
    nextCheck: (nextCheck != null && nextCheck.trim().isNotEmpty)
        ? nextCheck.trim()
        : null,
    tags: buildMomentTags(original, resultHint: hint),
    languageCode: languageCode,
    source: source,
  );
}

String? _normalizeHint(String? resultHint) {
  switch (resultHint) {
    case 'lighter':
      return 'lighter';
    case 'heavier':
      return 'heavier';
    case 'same':
    case 'showed_up_again':
      return 'same';
    case 'changed':
    case 'not_today':
    case 'none_fit':
      return 'changed';
    default:
      return null;
  }
}

String _title({String? patternTitle, String? hint}) {
  if (patternTitle != null && patternTitle.trim().isNotEmpty) {
    return patternTitle.trim();
  }
  switch (hint) {
    case 'same':
      return 'A pattern showed up again';
    case 'lighter':
      return 'Something felt lighter';
    case 'heavier':
      return 'Something felt heavier';
    case 'changed':
      return 'Something changed';
    default:
      return 'Moment from today';
  }
}

/// The clearest sentence, or the first useful clause, trimmed to a short line.
String _shortSummary(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  final sentences = trimmed
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  var candidate = sentences.isNotEmpty ? sentences.first : trimmed;
  // Prefer the first sentence that names a concrete moment/feeling.
  for (final s in sentences) {
    if (_momentCues.any((c) => s.toLowerCase().contains(c))) {
      candidate = s;
      break;
    }
  }
  if (candidate.length <= 120) return candidate;
  final clipped = candidate.substring(0, 120);
  final lastSpace = clipped.lastIndexOf(' ');
  return '${clipped.substring(0, lastSpace > 40 ? lastSpace : 120).trim()}…';
}

const List<String> _momentCues = [
  'when',
  'after',
  'before',
  'because',
  'while',
];