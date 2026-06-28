import '../../models/journal_entry.dart';
import '../timeline/timeline_entry_display.dart';
import 'archive_pattern_copy_guard.dart';

/// Detects saved moments too thin to support archive/belief/repeat claims.
abstract final class ArchiveEntrySignalGuard {
  ArchiveEntrySignalGuard._();

  static const minMeaningfulCharacters = 20;

  static const _placeholderTokens = {
    'asdf',
    'blah',
    'foo',
    'bar',
    'hello',
    'hi',
    'hey',
    'hiya',
    'hm',
    'hmm',
    'idk',
    'lol',
    'meh',
    'no',
    'ok',
    'okay',
    'random',
    'test',
    'testing',
    'yes',
  };

  static const _fillerTokens = {'um', 'uh', 'erm', 'like', 'yeah', 'yep', 'nope'};

  /// True when [entry] lacks enough user wording to connect archive insight.
  static bool isLowSignalEntry(JournalEntry entry) =>
      isLowSignalText(captureTextForGuard(entry));

  /// True when saved text lacks enough natural-language content for patterns.
  static bool isLowSignalText(String? raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return true;
    if (ArchivePatternCopyGuard.isBlockedPatternText(normalized)) return true;
    if (_meaningfulCharacterCount(normalized) < minMeaningfulCharacters) {
      return true;
    }
    if (_isPlaceholder(normalized)) return true;
    if (_isMostlyPunctuationOrNumbers(normalized)) return true;
    if (_isRepeatedFiller(normalized)) return true;
    if (!_hasEnoughNaturalLanguage(normalized)) return true;
    return false;
  }

  /// User-authored capture text only — transcript first, never AI observation.
  static String captureTextForGuard(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    if (transcript.isNotEmpty &&
        !transcript.startsWith('[draft]') &&
        !isDraftOrSystemTranscriptPlaceholder(transcript)) {
      return transcript;
    }
    return resolveEntryDisplayText(entry).text.trim();
  }

  static JournalEntry? newestEntry(Iterable<JournalEntry> entries) {
    JournalEntry? newest;
    for (final entry in entries) {
      if (newest == null || entry.createdAt.isAfter(newest.createdAt)) {
        newest = entry;
      }
    }
    return newest;
  }

  static bool newestEntryIsLowSignal(Iterable<JournalEntry> entries) {
    final newest = newestEntry(entries);
    if (newest == null) return false;
    return isLowSignalEntry(newest);
  }

  static String _normalize(String? raw) {
    return (raw ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  static int _meaningfulCharacterCount(String text) {
    return RegExp(r'[a-z]').allMatches(text).length;
  }

  static bool _isPlaceholder(String normalized) {
    final stripped = normalized.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (stripped.isEmpty) return true;

    final words = stripped.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final wordList = words.toList();
    if (wordList.isEmpty) return true;

    if (wordList.length == 1 && _placeholderTokens.contains(wordList.single)) {
      return true;
    }

    if (wordList.every(_placeholderTokens.contains)) return true;

    return false;
  }

  static bool _isMostlyPunctuationOrNumbers(String normalized) {
    final withoutNoise = normalized.replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');
    if (withoutNoise.isEmpty) return true;
    return RegExp(r'^[0-9]+$').hasMatch(withoutNoise);
  }

  static bool _isRepeatedFiller(String normalized) {
    final words = normalized
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < 2) return false;
    if (words.toSet().length == 1 && _fillerTokens.contains(words.first)) {
      return true;
    }
    return false;
  }

  static bool _hasEnoughNaturalLanguage(String normalized) {
    final words = normalized
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toList();
    return words.length >= 3 ||
        (words.length == 2 && words.every((w) => w.length >= 4));
  }
}
