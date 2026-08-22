import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_palette.dart';
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
                  onPressed: () =>
                      widget.onOpenEntry!(widget.evidence.entryId),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// Explicit "nothing to quote" state.
///
/// Rendered instead of a citation when a claim's supporting text cannot be
/// found in a saved entry. It is styled unlike [EvidenceCitationCard] on
/// purpose: a user should never mistake an unproven claim for a proven one.
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

/// Verifies a claim's supporting lines and renders a citation per verified
/// quote, or one [UngroundedEvidenceNotice] when none survive verification.
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
  });

  final List<InsightEvidenceLine> lines;
  final int maxCitations;
  final ValueChanged<String>? onOpenEntry;

  /// When false the claim shows nothing rather than an explicit empty state.
  /// Only appropriate where the claim itself is also suppressed.
  final bool showUngroundedNotice;

  static const Key listKey = Key('evidence_citation_list');

  @override
  Widget build(BuildContext context) {
    final verified = VerbatimEvidenceVerifier.groundLines(lines);

    if (verified.isEmpty) {
      if (!showUngroundedNotice) return const SizedBox.shrink();
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
