import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_palette.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Compact inline form of [EvidenceCitationCard] for dense pattern rows.
///
/// Shows one line of the stored quote plus its date, and expands in place to
/// the full [EvidenceCitationCard] when tapped. Like the card, it can only be
/// built from a [VerbatimEvidence], so a chip never shows generated text.
class SourceQuoteChip extends StatefulWidget {
  const SourceQuoteChip({
    required this.evidence,
    super.key,
    this.onOpenEntry,
  });

  final VerbatimEvidence evidence;
  final ValueChanged<String>? onOpenEntry;

  static const Key chipKey = Key('source_quote_chip');
  static const Key chipTextKey = Key('source_quote_chip_text');

  @override
  State<SourceQuoteChip> createState() => _SourceQuoteChipState();
}

class _SourceQuoteChipState extends State<SourceQuoteChip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (_expanded) {
      return EvidenceCitationCard(
        evidence: widget.evidence,
        onOpenEntry: widget.onOpenEntry,
        initiallyExpanded: true,
      );
    }

    final palette = EvidenceCitationPalette.of(context);
    final quoteStyle = ArchiveMobileTypography.responsiveHelper(
      context,
      color: palette.quoteText,
    ).copyWith(height: 1.35);
    final metaStyle = ArchiveMobileTypography.responsiveHelper(
      context,
      color: palette.quoteMeta,
    ).copyWith(fontWeight: FontWeight.w600);

    final recorded = widget.evidence.recordedAt;
    final recordedLabel = recorded == null
        ? ''
        : EvidenceCitationCopy.recordedOn(formatUserFacingDate(recorded));

    return Semantics(
      container: true,
      button: true,
      label: EvidenceCitationCopy.truncatedQuotationSemantics(
        quote: widget.evidence.text,
        recorded: recordedLabel,
      ),
      excludeSemantics: true,
      child: Material(
        color: palette.quoteBackground,
        borderRadius: BorderRadius.circular(EvidenceCitationMetrics.radius),
        child: InkWell(
          key: SourceQuoteChip.chipKey,
          onTap: () => setState(() => _expanded = true),
          borderRadius: BorderRadius.circular(EvidenceCitationMetrics.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                EvidenceCitationMetrics.radius,
              ),
              border: Border.all(
                color: palette.quoteBorder,
                width: EvidenceCitationMetrics.borderWidth,
              ),
            ),
            // Wrap so the quote, date, and affordance reflow instead of
            // overflowing once text is scaled up.
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: 2,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: (quoteStyle.fontSize ?? 13) + 3,
                  color: palette.quoteAccent,
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.6,
                  ),
                  child: Text(
                    '\u201C${widget.evidence.text}\u201D',
                    key: SourceQuoteChip.chipTextKey,
                    style: quoteStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (recordedLabel.isNotEmpty)
                  Text(recordedLabel, style: metaStyle),
                Text(
                  EvidenceCitationCopy.expandQuote,
                  style: metaStyle.copyWith(
                    color: palette.quoteAccent,
                    decoration: TextDecoration.underline,
                    decorationColor: palette.quoteAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
