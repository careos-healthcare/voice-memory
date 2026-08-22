import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

class BlindSpotEvidenceQuote {
  const BlindSpotEvidenceQuote({
    required this.entryId,
    required this.dateLabel,
    required this.quote,
  });

  final String entryId;
  final String dateLabel;
  final String quote;
}

class BlindSpotLocalReview {
  const BlindSpotLocalReview({
    required this.reviewId,
    required this.headline,
    required this.observation,
    required this.possiblePattern,
    required this.whyMayMatter,
    required this.experiment,
    required this.evidenceQuotes,
    required this.reflectionCount,
  });

  final String reviewId;
  final String headline;
  final String observation;
  final String possiblePattern;
  final String whyMayMatter;
  final String experiment;
  final List<BlindSpotEvidenceQuote> evidenceQuotes;
  final int reflectionCount;
}

/// Simplified on-device pattern review — not the full web engine.
class BlindSpotLocalEngine {
  static const int minReflections = AppConfig.patternReviewReflectionTarget;

  static BlindSpotLocalReview? buildReview(List<JournalEntry> entries) {
    final eligible =
        entries.where((e) => e.transcript.trim().length > 20).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (eligible.length < minReflections) return null;

    final themes = <String, int>{};
    for (final e in eligible) {
      for (final t in e.reflection.recurringThemes) {
        final key = t.trim().toLowerCase();
        if (key.isEmpty) continue;
        themes[key] = (themes[key] ?? 0) + 1;
      }
    }
    final topTheme = themes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final headline = topTheme.isNotEmpty
        ? 'You may keep returning to “${topTheme.first.key}”.'
        : 'A repeated concern may be forming across reflections.';

    final quotes = eligible.take(3).map((e) {
      final snippet = e.transcript.length > 160
          ? '${e.transcript.substring(0, 160)}…'
          : e.transcript;
      return BlindSpotEvidenceQuote(
        entryId: e.id,
        dateLabel: e.createdAt.toLocal().toString().split(' ').first,
        quote: snippet,
      );
    }).toList();

    final latest = eligible.first;
    return BlindSpotLocalReview(
      reviewId: 'local:${topTheme.isNotEmpty ? topTheme.first.key : 'pattern'}',
      headline: headline,
      observation: latest.reflection.concreteObservation.isNotEmpty
          ? latest.reflection.concreteObservation
          : latest.reflection.exactLanguagePattern,
      possiblePattern: latest.reflection.repeatedSignal.isNotEmpty
          ? latest.reflection.repeatedSignal
          : 'Similar language may be showing up across weeks.',
      whyMayMatter:
          'This is a hypothesis from your archive — not a diagnosis. It may matter if the same tension keeps costing attention.',
      experiment:
          latest.reflection.nextSmallAction ??
          'Notice once this week when the same worry appears without you planning it.',
      evidenceQuotes: quotes,
      reflectionCount: eligible.length,
    );
  }
}