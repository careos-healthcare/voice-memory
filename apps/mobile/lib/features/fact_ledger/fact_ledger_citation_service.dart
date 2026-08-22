import 'package:archiveme_mobile/features/contradiction_detection/statement_analysis.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_sqlite_repository.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Indexes and resolves exact word citations for pattern/change surfaces.
///
/// System citations are written to [FactLedgerStore] and the SQLite
/// `fact_ledger` mirror on journal save; renderers query the in-memory cache
/// (hydrated from SQLite/prefs) before falling back to raw entry text.
abstract final class FactLedgerCitationService {
  FactLedgerCitationService._();

  static final Map<String, List<String>> _quotesByEntryId = {};
  static final Set<String> _indexedEntryIds = {};

  static String citationIdFor(String entryId, String quote) {
    final hash = UserContentSafety.privacyHash(quote.trim());
    return 'cite_${entryId}_$hash';
  }

  /// Persists and caches one exact quote for an entry.
  static Future<void> indexQuote({
    required String sourceEntryId,
    required String quote,
    required String provenance,
    FactLedgerStore? store,
    FactLedgerSqliteRepository? repository,
  }) async {
    final trimmed = quote.trim();
    if (trimmed.isEmpty || sourceEntryId.isEmpty) return;

    _rememberQuote(sourceEntryId, trimmed);

    final resolvedStore = store ?? _storeOrNull();
    if (resolvedStore == null) return;

    final fact = await resolvedStore.upsertSystemCitation(
      id: citationIdFor(sourceEntryId, trimmed),
      sourceEntryId: sourceEntryId,
      quote: trimmed,
      provenance: provenance,
    );
    if (fact == null) return;

    final repo = repository ?? _repositoryOrNull();
    if (repo != null) {
      await repo.upsert(fact);
    }
  }

  /// Indexes transcript/reflection lines and all verified proof evidence.
  static Future<void> indexEntry(
    JournalEntry entry, {
    FactLedgerStore? store,
    FactLedgerSqliteRepository? repository,
  }) async {
    if (_indexedEntryIds.contains(entry.id)) return;

    for (final text in archiveStatementTexts(entry)) {
      await indexQuote(
        sourceEntryId: entry.id,
        quote: text,
        provenance: 'entry_statement',
        store: store,
        repository: repository,
      );
    }

    final proof = entry.verifiedProof;
    if (proof != null) {
      await indexProof(
        proof,
        store: store,
        repository: repository,
      );
    }

    _indexedEntryIds.add(entry.id);
  }

  static Future<void> indexProof(
    VerifiedProof proof, {
    FactLedgerStore? store,
    FactLedgerSqliteRepository? repository,
  }) async {
    final receipt = proof.qualityReceipt;
    final snapshots = [
      ...receipt.supportingEvidence,
      ...receipt.counterexamples,
      ...receipt.contradictions,
    ];
    for (final item in snapshots) {
      await indexQuote(
        sourceEntryId: item.sourceEntryId,
        quote: item.quote,
        provenance: 'proof:${proof.proofId}',
        store: store,
        repository: repository,
      );
    }
  }

  static Future<void> indexEvidenceLines(
    Iterable<InsightEvidenceLine> lines, {
    required String provenance,
    FactLedgerStore? store,
    FactLedgerSqliteRepository? repository,
  }) async {
    for (final line in lines) {
      await indexQuote(
        sourceEntryId: line.entryId,
        quote: line.quote,
        provenance: provenance,
        store: store,
        repository: repository,
      );
    }
  }

  /// Backfills citations for entries not yet indexed this session.
  static Future<void> ensureIndexed(
    Iterable<JournalEntry> entries, {
    FactLedgerStore? store,
    FactLedgerSqliteRepository? repository,
  }) async {
    for (final entry in entries) {
      await indexEntry(entry, store: store, repository: repository);
    }
  }

  /// Loads evidence citations from SQLite/prefs into the resolver cache.
  static Future<void> warmCache({
    FactLedgerStore? store,
    FactLedgerSqliteRepository? repository,
  }) async {
    final repo = repository ?? _repositoryOrNull();
    if (repo != null) {
      final citations = await repo.loadEvidenceCitations();
      for (final fact in citations) {
        _rememberQuote(fact.sourceEntryId, fact.value);
      }
      return;
    }

    final resolvedStore = store ?? _storeOrNull();
    if (resolvedStore == null) return;

    final all = await resolvedStore.loadAll();
    for (final fact in all) {
      if (fact.factType != FactType.evidenceCitation.id) continue;
      _rememberQuote(fact.sourceEntryId, fact.value);
    }
  }

  /// Returns the ledger-backed exact quote when indexed; otherwise [fallback].
  static String resolve({
    required String entryId,
    required String fallback,
  }) {
    final trimmedFallback = fallback.trim();
    if (trimmedFallback.isEmpty) return trimmedFallback;

    final indexed = _quotesByEntryId[entryId];
    if (indexed == null || indexed.isEmpty) return trimmedFallback;

    for (final quote in indexed) {
      if (quote == trimmedFallback) return quote;
    }

    String? best;
    for (final quote in indexed) {
      if (trimmedFallback.contains(quote) ||
          quote.contains(trimmedFallback)) {
        if (best == null || quote.length > best.length) {
          best = quote;
        }
      }
    }
    return best ?? trimmedFallback;
  }

  static String resolvedSnippet({
    required String entryId,
    required String fallbackText,
    int maxLength = 120,
  }) {
    final resolved = resolve(entryId: entryId, fallback: fallbackText);
    final trimmed = resolved.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength - 1)}…';
  }

  /// Test-only reset.
  static void resetForTest() {
    _quotesByEntryId.clear();
    _indexedEntryIds.clear();
  }

  static void _rememberQuote(String entryId, String quote) {
    final trimmed = quote.trim();
    if (trimmed.isEmpty) return;
    final existing = _quotesByEntryId.putIfAbsent(entryId, () => []);
    if (!existing.contains(trimmed)) {
      existing.add(trimmed);
    }
  }

  static FactLedgerStore? _storeOrNull() {
    if (!AppServices.isInitialized) return null;
    return FactLedgerStore(AppServices.instance.prefs);
  }

  static FactLedgerSqliteRepository? _repositoryOrNull() {
    if (!AppServices.isInitialized) return null;
    return FactLedgerSqliteRepository.fromAppServicesDatabase(
      AppServices.instance.sqliteDatabase,
    );
  }
}
