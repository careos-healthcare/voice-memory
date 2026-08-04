import '../explainable_conclusion/explainable_conclusion.dart';
import '../memory/sensitive_surfacing_policy.dart';
import 'change_resurfacing.dart';
import 'change_thread.dart';

/// Decides which quotes a compact, always-visible surface may carry.
///
/// The thread detail is something the user opened on purpose; a list row is
/// not. A row therefore only quotes moments whose source still exists and
/// whose surfacing choice allows them to appear unasked. When it may not
/// quote, the row still exists — the user keeps the thread, just not the words
/// on the outside of it.
abstract final class ChangeEvidenceVisibility {
  ChangeEvidenceVisibility._();

  /// The strongest excerpt a list row may show, or null when it may show none.
  static String? safeExcerpt(
    ChangeThreadView view, {
    required ChangeResurfacingContext context,
  }) {
    if (view.events.isEmpty) return null;
    final citation = view.events.last.nowEvidence;
    if (!mayQuoteUnasked(citation, context: context)) return null;
    final quote = citation.quote.trim();
    return quote.isEmpty ? null : quote;
  }

  static bool mayQuoteUnasked(
    TranscriptEvidenceCitation citation, {
    required ChangeResurfacingContext context,
  }) {
    if (!context.liveEntryIds.contains(citation.entryId)) return false;
    return SensitiveSurfacingPolicy.evaluate(
          mode: context.modeFor(citation.entryId),
          surfaceType: MemorySurfaceType.threadReturn,
        ) ==
        SensitiveSurfacingOutcome.allowed;
  }
}
