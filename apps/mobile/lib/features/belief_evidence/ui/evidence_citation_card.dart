import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/legacy_transcript_registry.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_palette.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_notice.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Shared geometry so the card and the chip read as one component family.
abstract final class EvidenceCitationMetrics {
  EvidenceCitationMetrics._();

  static const double radius = 12;
  static const double borderWidth = 1.5;
  static const int collapsedQuoteLines = 4;
}

/// A quote taken character for character from a saved entry, shown directly
/// under the claim it supports.
///
/// Takes a [VerbatimEvidence], which only [VerbatimEvidenceVerifier] can
/// produce, so this widget cannot be handed generated text to display. When a
/// claim has nothing to quote, render [UngroundedEvidenceNotice] instead —
/// never this card with placeholder text.
class EvidenceCitationCard extends StatefulWidget {
  const EvidenceCitationCard({
    required this.evidence,
    super.key,
    this.onOpenEntry,
    this.initiallyExpanded = false,
  });

  final VerbatimEvidence evidence;
  final ValueChanged<String>? onOpenEntry;
  final bool initiallyExpanded;

  static const Key cardKey = Key('evidence_citation_card');
  static const Key quoteTextKey = Key('evidence_citation_quote_text');
  static const Key expandKey = Key('evidence_citation_expand');
  static const Key openEntryKey = Key('evidence_citation_open_entry');

  /// Same 48pt minimum as View evidence / source-proof links.
  static const double minTapTarget = 48;

  @override
  State<EvidenceCitationCard> createState() => _EvidenceCitationCardState();
}

class _EvidenceCitationCardState extends State<EvidenceCitationCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final palette = EvidenceCitationPalette.of(context);
    final quoteStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: palette.quoteText, height: 1.45);
    final metaStyle = ArchiveMobileTypography.responsiveHelper(
      context,
      color: palette.quoteMeta,
    ).copyWith(fontWeight: FontWeight.w600);
    final labelStyle = ArchiveMobileTypography.cardLabel(
      context,
      color: palette.quoteAccent,
    ).copyWith(fontWeight: FontWeight.w700);

    final recorded = widget.evidence.recordedAt;
    final recordedLabel = recorded == null
        ? null
        : EvidenceCitationCopy.recordedOn(formatUserFacingDate(recorded));

    return Semantics(
      container: true,
      // The claim above is already read out; this node must announce itself as
      // a quotation with its date so the two are not merged into one string.
      label: _semanticsLabel(recordedLabel),
      excludeSemantics: true,
      child: Container(
        key: EvidenceCitationCard.cardKey,
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.quoteBackground,
          borderRadius: BorderRadius.circular(EvidenceCitationMetrics.radius),
          border: Border.all(
            color: palette.quoteBorder,
            width: EvidenceCitationMetrics.borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap, not Row: at large text scales the label and the date need
            // to fall onto separate lines instead of overflowing.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: (labelStyle.fontSize ?? 14) + 4,
                      color: palette.quoteAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(EvidenceCitationCopy.quoteLabel, style: labelStyle),
                  ],
                ),
                if (recordedLabel != null)
                  Text(recordedLabel, style: metaStyle),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _ExpandableQuote(
              text: widget.evidence.text,
              style: quoteStyle,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              EvidenceCitationCopy.verbatimHelper,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
                color: palette.quoteMeta,
              ),
            ),
            if (widget.onOpenEntry != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: EvidenceCitationCard.openEntryKey,
                  onPressed: () =>
                      widget.onOpenEntry!(widget.evidence.entryId),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      EvidenceCitationCard.minTapTarget,
                      EvidenceCitationCard.minTapTarget,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    foregroundColor: palette.quoteAccent,
                  ),
                  child: const Text(EvidenceCitationCopy.openEntry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _semanticsLabel(String? recordedLabel) {
    final recorded = recordedLabel ?? '';
    return EvidenceCitationCopy.quotationSemantics(
      quote: widget.evidence.text,
      recorded: recorded,
    );
  }
}

/// Quote text that only offers an expand control when it genuinely overflowed.
class _ExpandableQuote extends StatelessWidget {
  const _ExpandableQuote({
    required this.text,
    required this.style,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final TextStyle style;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = EvidenceCitationPalette.of(context);
    final display = '\u201C$text\u201D';

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: display, style: style),
          maxLines: EvidenceCitationMetrics.collapsedQuoteLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              display,
              key: EvidenceCitationCard.quoteTextKey,
              style: style,
              maxLines: expanded
                  ? null
                  : EvidenceCitationMetrics.collapsedQuoteLines,
              // Ellipsis rather than a clip so a shortened quote never looks
              // like the whole of what was said.
              overflow: expanded
                  ? TextOverflow.clip
                  : TextOverflow.ellipsis,
            ),
            if (overflows)
              TextButton(
                key: EvidenceCitationCard.expandKey,
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    EvidenceCitationCard.minTapTarget,
                    EvidenceCitationCard.minTapTarget,
                  ),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  foregroundColor: palette.quoteAccent,
                ),
                child: Text(
                  expanded
                      ? EvidenceCitationCopy.collapseQuote
                      : EvidenceCitationCopy.expandQuote,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Explicit "the archive does not support this" state.
///
/// Rendered instead of a citation when a claim's supporting text cannot be
/// found in a saved entry. It is styled unlike [EvidenceCitationCard] on
/// purpose: a user should never mistake an unproven claim for a proven one.
///
/// Not for entries whose transcript origin was not recorded — those have
/// intact text behind them and get [LegacyProvenanceNotice]. Sending them here
/// would report an unsupported claim where the real situation is a supported
/// one the app declines to quote.
class UngroundedEvidenceNotice extends StatelessWidget {
  const UngroundedEvidenceNotice({required this.failure, super.key});

  final EvidenceGroundingFailure failure;

  static const Key noticeKey = Key('ungrounded_evidence_notice');

  bool get _isSourceUnavailable =>
      failure == EvidenceGroundingFailure.sourceUnavailable;

  String get title => _isSourceUnavailable
      ? EvidenceCitationCopy.sourceUnavailableTitle
      : EvidenceCitationCopy.ungroundedTitle;

  String get body => _isSourceUnavailable
      ? EvidenceCitationCopy.sourceUnavailableHelper
      : EvidenceCitationCopy.ungroundedHelper;

  @override
  Widget build(BuildContext context) {
    final palette = EvidenceCitationPalette.of(context);
    final titleStyle = ArchiveMobileTypography.cardLabel(
      context,
      color: palette.ungroundedTitle,
    ).copyWith(fontWeight: FontWeight.w700);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
      color: palette.ungroundedBody,
    );

    return Semantics(
      container: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: Container(
        key: UngroundedEvidenceNotice.noticeKey,
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.ungroundedBackground,
          borderRadius: BorderRadius.circular(EvidenceCitationMetrics.radius),
          border: Border.all(color: palette.ungroundedBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: (titleStyle.fontSize ?? 14) + 4,
              color: palette.ungroundedIcon,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: 2),
                  Text(body, style: bodyStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three things that can be true of a claim's supporting evidence.
///
/// Before this existed there were two, and the second covered both "the
/// archive contradicts or does not contain this" and "the entry behind this
/// was written before the app recorded where its text came from". Those are
/// different facts about different data, and a user told the second when the
/// first was meant learns something false about their own history.
enum EvidenceCitationState {
  /// A verified verbatim quote is available.
  quoted,

  /// A transcript exists but its origin cannot be attributed to the user.
  provenanceUnverified,

  /// The archive does not support the claim.
  unsupported,
}

/// Verifies a claim's supporting lines and renders a citation per verified
/// quote, or the notice that matches why no quote survived.
///
/// This is the integration point for insight surfaces: pass the lines the
/// engine produced and the widget decides, from stored text, what may be shown.
class EvidenceCitationList extends StatelessWidget {
  const EvidenceCitationList({
    required this.lines,
    super.key,
    this.maxCitations = 2,
    this.onOpenEntry,
    this.showUngroundedNotice = true,
    this.recoveryBuilder,
  });

  final List<InsightEvidenceLine> lines;
  final int maxCitations;
  final ValueChanged<String>? onOpenEntry;

  /// When false the claim shows nothing rather than an explicit empty state.
  /// Only appropriate where the claim itself is also suppressed.
  final bool showUngroundedNotice;

  /// Supplies the recover affordance for entries with unverifiable origin.
  ///
  /// Injected because consent state and the filesystem have no business being
  /// reachable from a citation widget, and because a surface that cannot offer
  /// recovery should simply pass nothing.
  final Widget Function(BuildContext context, List<String> entryIds)?
  recoveryBuilder;

  static const Key listKey = Key('evidence_citation_list');

  /// Which of the three states applies to [lines].
  ///
  /// An unverifiable origin outranks [EvidenceGroundingFailure.sourceUnavailable]
  /// — a legacy entry is never in the evidence index, so it always reports as
  /// unavailable, and "Quote not loaded" reads as a transient hiccup for what
  /// is a permanent property of that row.
  ///
  /// It does not outrank [EvidenceGroundingFailure.notPresentInSource]. That
  /// failure means some other entry's stored text was read and does not
  /// contain the words, and the honest thing to say about a claim like that is
  /// still that the archive does not back it.
  static EvidenceCitationState stateFor(List<InsightEvidenceLine> lines) {
    if (VerbatimEvidenceVerifier.groundLines(lines).isNotEmpty) {
      return EvidenceCitationState.quoted;
    }
    final failure = VerbatimEvidenceVerifier.summariseFailure(lines);
    if (failure != EvidenceGroundingFailure.notPresentInSource &&
        lines.any((line) => LegacyTranscriptRegistry.isLegacy(line.entryId))) {
      return EvidenceCitationState.provenanceUnverified;
    }
    return EvidenceCitationState.unsupported;
  }

  /// Entry ids in [lines] whose transcript origin is unverifiable, in order
  /// and without repeats, so a recover action can name its own scope.
  static List<String> legacyEntryIds(List<InsightEvidenceLine> lines) {
    final seen = <String>{};
    return [
      for (final line in lines)
        if (LegacyTranscriptRegistry.isLegacy(line.entryId) &&
            seen.add(line.entryId))
          line.entryId,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final verified = VerbatimEvidenceVerifier.groundLines(lines);

    if (verified.isEmpty) {
      if (!showUngroundedNotice) return const SizedBox.shrink();
      if (stateFor(lines) == EvidenceCitationState.provenanceUnverified) {
        final entryIds = legacyEntryIds(lines);
        return LegacyProvenanceNotice(
          recovery: recoveryBuilder?.call(context, entryIds),
        );
      }
      return UngroundedEvidenceNotice(
        failure: VerbatimEvidenceVerifier.summariseFailure(lines),
      );
    }

    final shown = verified.take(maxCitations).toList();
    return Column(
      key: EvidenceCitationList.listKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          EvidenceCitationCard(
            evidence: shown[i],
            onOpenEntry: onOpenEntry,
          ),
        ],
      ],
    );
  }
}
