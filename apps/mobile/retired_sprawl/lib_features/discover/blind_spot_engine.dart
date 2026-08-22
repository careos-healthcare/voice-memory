import 'package:archiveme_mobile/features/blind_spots/blind_spot_local.dart';
import 'package:archiveme_mobile/features/discover/discover_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Blind spot cards for Discover Yourself (local inference only).
class DiscoverBlindSpotEngine {
  const DiscoverBlindSpotEngine();

  List<DiscoverBlindSpotCard> build(List<JournalEntry> entries) {
    if (entries.length < 5) return const [];

    final cards = <DiscoverBlindSpotCard>[];
    final primary = BlindSpotLocalEngine.buildReview(entries);
    if (primary != null) {
      cards.add(_fromReview(primary));
    }

    final extra = _secondarySpots(entries);
    for (final spot in extra) {
      if (cards.length >= 4) break;
      if (cards.any((c) => c.id == spot.id)) continue;
      cards.add(spot);
    }

    return cards;
  }

  DiscoverBlindSpotCard _fromReview(BlindSpotLocalReview review) {
    return DiscoverBlindSpotCard(
      id: review.reviewId,
      headline: review.headline,
      observation: review.observation,
      confidence: 72,
      evidenceCount: review.evidenceQuotes.length,
      entryIds: review.evidenceQuotes.map((q) => q.entryId).toList(),
    );
  }

  List<DiscoverBlindSpotCard> _secondarySpots(List<JournalEntry> entries) {
    final eligible =
        entries.where((e) => e.transcript.trim().length > 30).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final helpCount = eligible.where((e) {
      final t = e.transcript.toLowerCase();
      return t.contains('help') ||
          t.contains('support') ||
          t.contains('others');
    }).length;
    final planCount = eligible.where((e) {
      final t = e.transcript.toLowerCase();
      return t.contains('plan') || t.contains('future') || t.contains('next');
    }).length;

    final spots = <DiscoverBlindSpotCard>[];

    if (helpCount >= 3 && planCount >= 2) {
      spots.add(
        DiscoverBlindSpotCard(
          id: 'blindspot:help-vs-plans',
          headline:
              'You often describe helping others but rarely mention your own needs.',
          observation:
              'Across $helpCount reflections you focus on support for others, '
              'while future-planning language appears in $planCount recordings.',
          confidence: 65,
          evidenceCount: helpCount,
          entryIds: eligible.take(4).map((e) => e.id).toList(),
        ),
      );
    }

    if (planCount >= 4) {
      spots.add(
        DiscoverBlindSpotCard(
          id: 'blindspot:plans-without-wins',
          headline:
              'You frequently discuss future plans but rarely celebrate completed wins.',
          observation:
              'Future-oriented language shows up often; completion or celebration '
              'language is less common in your archive.',
          confidence: 62,
          evidenceCount: planCount,
          entryIds: eligible.take(4).map((e) => e.id).toList(),
        ),
      );
    }

    return spots;
  }
}