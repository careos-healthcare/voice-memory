import '../../product/consumer_copy_guard.dart';
import '../../security/user_content_safety.dart';
import '../../storage/journal_store.dart';
import '../archive_evidence/archive_evidence_guard.dart';

/// Builds the only prior-entry payload allowed on capture analysis requests.
///
/// It intentionally excludes transcripts, audio paths, account identifiers,
/// and generated fields beyond a short exact-language or observation snippet.
final class PriorAnalysisEvidenceBuilder {
  const PriorAnalysisEvidenceBuilder();

  static const int maxEntries = 3;
  static const int maxTextChars = 120;

  Future<List<Map<String, dynamic>>> build({
    required JournalStore journalStore,
    String? excludeEntryId,
  }) async {
    final all = await journalStore.loadAll();
    final eligible =
        ArchiveEvidenceGuard.eligibleEntries(
            all,
            analyticsSource: 'prior_analysis_evidence',
          ).where((entry) {
            if (entry.id == excludeEntryId || entry.treatAsNew) return false;
            final transcript = entry.transcript.trim();
            return !transcript.startsWith('[draft]') &&
                !ConsumerCopyGuard.isSystemObservation(transcript);
          }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final result = <Map<String, dynamic>>[];
    for (final entry in eligible) {
      if (result.length >= maxEntries) break;
      final phrase = _safeSnippet(entry.reflection.exactLanguagePattern);
      final observation = _safeSnippet(entry.reflection.concreteObservation);
      final item = <String, dynamic>{
        'id': entry.id,
        'createdAt': entry.createdAt.toUtc().toIso8601String(),
      };
      if (phrase != null) item['exactLanguagePattern'] = phrase;
      if (observation != null) item['concreteObservation'] = observation;
      result.add(item);
    }
    return result;
  }

  String? _safeSnippet(String raw) {
    final sanitized = UserContentSafety.sanitizePlainText(raw);
    if (sanitized.isEmpty ||
        UserContentSafety.looksLikePromptInjection(sanitized) ||
        UserContentSafety.containsPossibleSecret(sanitized) ||
        ConsumerCopyGuard.isSystemObservation(sanitized) ||
        _isInternalCopy(sanitized)) {
      return null;
    }
    return UserContentSafety.safeSnippet(sanitized, maxChars: maxTextChars);
  }

  bool _isInternalCopy(String text) {
    final lower = text.toLowerCase();
    const blocked = [
      '[draft]',
      'saved locally',
      'saved on this device',
      'transcribe when connected',
      'cloud processing pending',
      'recorded reflection',
      'entry language',
    ];
    return blocked.any(lower.contains);
  }
}
