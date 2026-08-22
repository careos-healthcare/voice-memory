import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_service.dart';
import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_calculator.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_sqlite_repository.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/journal_entry/journal_entry_backlink_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Resolves reverse evidence links from fact ledger + archive evidence engines.
abstract final class JournalEntryBacklinkService {
  JournalEntryBacklinkService._();

  /// Insights currently citing [entryId] via archive evidence or fact ledger.
  static Future<List<JournalEntryDerivedInsight>> getDerivedInsights(
    String entryId, {
    JournalStore? journalStore,
    FactLedgerStore? factStore,
    BeliefEvolutionService? evolutionService,
  }) async {
    final snapshot = await loadBacklinkSnapshot(
      entryId,
      journalStore: journalStore,
      factStore: factStore,
      evolutionService: evolutionService,
    );
    return snapshot.derivedInsights;
  }

  static Future<JournalEntryBacklinkSnapshot> loadBacklinkSnapshot(
    String entryId, {
    JournalStore? journalStore,
    FactLedgerStore? factStore,
    BeliefEvolutionService? evolutionService,
  }) async {
    final trimmedId = entryId.trim();
    if (trimmedId.isEmpty) return const JournalEntryBacklinkSnapshot.empty();

    final facts = await _factsForEntry(trimmedId, factStore: factStore);
    final store = journalStore ?? _journalStoreOrNull();
    if (store == null) {
      return JournalEntryBacklinkSnapshot(
        derivedInsights: const [],
        quoteHighlights: _quoteHighlights(
          transcript: '',
          facts: facts,
          insights: const [],
        ),
      );
    }

    final entries = await store.loadAll();
    final entry = entries.where((e) => e.id == trimmedId).firstOrNull;
    if (entry == null) return const JournalEntryBacklinkSnapshot.empty();

    final derived = await _insightsFromArchiveEvidence(
      entryId: trimmedId,
      entries: entries,
      facts: facts,
      evolutionService: evolutionService,
    );

    final transcript = _transcriptForHighlighting(entry);
    final highlights = _quoteHighlights(
      transcript: transcript,
      facts: facts,
      insights: derived,
    );

    return JournalEntryBacklinkSnapshot(
      derivedInsights: derived,
      quoteHighlights: highlights,
    );
  }

  static Future<List<ArchiveFact>> _factsForEntry(
    String entryId, {
    FactLedgerStore? factStore,
  }) async {
    if (AppServices.isInitialized) {
      final sqlite = AppServices.instance.sqliteDatabase;
      final repository = FactLedgerSqliteRepository.fromAppServicesDatabase(
        sqlite,
      );
      if (repository != null) {
        await repository.ensureBackfilledFromPrefs(AppServices.instance.prefs);
        return repository.forEntry(entryId);
      }
    }

    final store =
        factStore ??
        (AppServices.isInitialized
            ? FactLedgerStore(AppServices.instance.prefs)
            : null);
    if (store == null) return const [];
    return store.forEntry(entryId);
  }

  static JournalStore? _journalStoreOrNull() {
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.journalStore;
  }

  static Future<List<JournalEntryDerivedInsight>> _insightsFromArchiveEvidence({
    required String entryId,
    required List<JournalEntry> entries,
    required List<ArchiveFact> facts,
    BeliefEvolutionService? evolutionService,
  }) async {
    if (!archiveHasMinimumEvidence(entries)) return const [];

    final evo = evolutionService ??
        (AppServices.isInitialized ? AppServices.instance.beliefEvolution : null);
    if (evo == null) return const [];

    final view = await const ArchiveV1Builder().build(
      entries: entries,
      evolutionService: evo,
    );

    final factIds = facts.map((fact) => fact.id).toList(growable: false);
    final out = <JournalEntryDerivedInsight>[];

    final belief = view.belief;
    if (belief != null &&
        belief.supportingEntries.any((entry) => entry.id == entryId)) {
      out.add(
        JournalEntryDerivedInsight(
          id: 'belief_primary',
          kind: JournalEntryDerivedInsightKind.belief,
          title: belief.statement.trim(),
          subtitle:
              '${belief.evidenceCount} supporting ${belief.evidenceCount == 1 ? 'entry' : 'entries'}',
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            belief.confidencePercent,
          ),
          supportingFactIds: factIds,
        ),
      );
    }

    for (final contradiction in view.contradictions) {
      if (!contradiction.entryIds.contains(entryId)) continue;
      out.add(
        JournalEntryDerivedInsight(
          id: contradiction.id,
          kind: JournalEntryDerivedInsightKind.contradiction,
          title: contradiction.youSay.trim(),
          subtitle: contradiction.but.trim(),
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            contradiction.confidenceScore,
          ),
          supportingFactIds: factIds,
        ),
      );
    }

    for (final spot in view.blindSpots) {
      if (!spot.entryIds.contains(entryId)) continue;
      out.add(
        JournalEntryDerivedInsight(
          id: spot.id,
          kind: JournalEntryDerivedInsightKind.blindSpot,
          title: spot.headline.trim(),
          subtitle: spot.observation.trim(),
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            spot.confidence,
          ),
          supportingFactIds: factIds,
        ),
      );
    }

    for (final surprise in view.surprises.observations) {
      if (!surprise.evidenceEntryIds.contains(entryId)) continue;
      out.add(
        JournalEntryDerivedInsight(
          id: surprise.id,
          kind: JournalEntryDerivedInsightKind.surprise,
          title: surprise.observation.trim(),
          subtitle: '${surprise.evidenceCount} citing entries',
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            surprise.confidenceScore,
          ),
          supportingFactIds: factIds,
        ),
      );
    }

    out.sort(
      (a, b) => a.confidenceBand.journalSortRank.compareTo(
        b.confidenceBand.journalSortRank,
      ),
    );

    return out;
  }

  static String _transcriptForHighlighting(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    if (transcript.isNotEmpty) return transcript;
    return entry.reflection.concreteObservation.trim();
  }

  static List<JournalEntryQuoteHighlight> _quoteHighlights({
    required String transcript,
    required List<ArchiveFact> facts,
    required List<JournalEntryDerivedInsight> insights,
  }) {
    if (transcript.isEmpty || facts.isEmpty) return const [];

    final sentences = _splitSentences(transcript);
    if (sentences.isEmpty) return const [];

    final highlights = <JournalEntryQuoteHighlight>[];
    for (final sentence in sentences) {
      final normalizedSentence = _normalize(sentence.text);
      if (normalizedSentence.length < 8) continue;

      final matchedValues = <String>[];
      for (final fact in facts) {
        final value = fact.value.trim();
        if (value.length < 8) continue;
        if (_normalize(value).length < 8) continue;
        if (normalizedSentence.contains(_normalize(value))) {
          matchedValues.add(value);
        }
      }

      if (matchedValues.isEmpty) continue;

      final linked = insights.isEmpty
          ? const <JournalEntryDerivedInsight>[]
          : [insights.first];

      highlights.add(
        JournalEntryQuoteHighlight(
          start: sentence.start,
          end: sentence.end,
          sentence: sentence.text,
          linkedInsights: linked,
          factValues: matchedValues,
        ),
      );
    }

    return highlights;
  }

  static List<_SentenceSpan> _splitSentences(String text) {
    final spans = <_SentenceSpan>[];
    final pattern = RegExp('[^.!?]+[.!?]?');
    for (final match in pattern.allMatches(text)) {
      final raw = match.group(0);
      if (raw == null) continue;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final leadingWhitespace = raw.indexOf(trimmed);
      final start = match.start + (leadingWhitespace < 0 ? 0 : leadingWhitespace);
      final end = start + trimmed.length;
      spans.add(_SentenceSpan(start, end, trimmed));
    }
    if (spans.isEmpty && text.trim().isNotEmpty) {
      final trimmed = text.trim();
      final start = text.indexOf(trimmed);
      spans.add(_SentenceSpan(start, start + trimmed.length, trimmed));
    }
    return spans;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _SentenceSpan {
  const _SentenceSpan(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}