import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_calculator.dart';
import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_copy.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:intl/intl.dart';

/// Side-by-side payloads for Experiment H comparison card.
class ChatGptVsEvidencePayload {
  const ChatGptVsEvidencePayload({
    required this.entry,
    required this.ephemeralSummary,
    required this.evidenceSummary,
    required this.quote,
    required this.recordedAtLabel,
    required this.confidenceBand,
    required this.isEmpty,
    required this.isShort,
    required this.factLedgerLines,
  });

  final JournalEntry entry;
  final String ephemeralSummary;
  final String evidenceSummary;
  final String quote;
  final String recordedAtLabel;
  final PatternMatchConfidenceBand confidenceBand;
  final bool isEmpty;
  final bool isShort;
  final List<String> factLedgerLines;
}

abstract final class ChatGptVsEvidenceBuilder {
  ChatGptVsEvidenceBuilder._();

  static const _minUsableChars = 24;

  static ChatGptVsEvidencePayload fromEntry(
    JournalEntry entry, {
    Insight? insight,
  }) {
    final transcript = entry.transcript.trim();
    final isEmpty = transcript.isEmpty &&
        entry.reflection.concreteObservation.trim().isEmpty;
    final isShort = !isEmpty && transcript.length < _minUsableChars;

    final quote = _quoteFor(entry);
    final recordedAtLabel = DateFormat('EEE, MMM d · h:mm a').format(
      entry.createdAt.toLocal(),
    );

    final band = insight?.confidenceBand ??
        EvidenceProofCalculator.resolveBand(citationCount: 1);

    final themes = entry.reflection.recurringThemes
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final themeHint = themes.isNotEmpty ? themes.first : 'what you shared';

    final ephemeralSummary = isEmpty
        ? 'It sounds like you are working through something — many chatbots would '
            'offer general reassurance here without saving your exact words.'
        : isShort
        ? 'You mentioned something about $themeHint. A chatbot might reflect that '
            'back generically, but would not keep a permanent, citable record.'
        : 'You seem to be noticing a pattern around $themeHint. Standard chat '
            'summaries often smooth over your wording and forget prior sessions.';

    final evidenceSummary = insight?.insightText ??
        (isEmpty
            ? ExperimentHCopy.emptyEntryBody
            : 'ArchiveMe saved this as a citable ledger moment — not a one-off reply.');

    final factLedgerLines = <String>[
      'entryId: ${entry.id}',
      'recordedAt: ${entry.createdAt.toUtc().toIso8601String()}',
      if (quote.isNotEmpty) 'verbatim: $quote',
      if (themes.isNotEmpty) 'themes: ${themes.join(', ')}',
    ];

    return ChatGptVsEvidencePayload(
      entry: entry,
      ephemeralSummary: ephemeralSummary,
      evidenceSummary: evidenceSummary,
      quote: quote,
      recordedAtLabel: recordedAtLabel,
      confidenceBand: band,
      isEmpty: isEmpty,
      isShort: isShort,
      factLedgerLines: factLedgerLines,
    );
  }

  static String _quoteFor(JournalEntry entry) {
    final exact = entry.reflection.exactLanguagePattern.trim();
    if (exact.length >= 12) {
      return exact.startsWith('"') ? exact : '"$exact"';
    }
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty) {
      final obs = entry.reflection.concreteObservation.trim();
      return obs.isEmpty ? '' : '"$obs"';
    }
    final line = transcript.length <= 180
        ? transcript
        : '${transcript.substring(0, 180).trim()}…';
    return '"$line"';
  }
}