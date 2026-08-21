import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Expandable fact-ledger citations — muted lead line plus source snippets.
class ViewSourceProofSection extends StatefulWidget {
  const ViewSourceProofSection({
    required this.citations,
    super.key,
    this.leadLine,
    this.showArchiveNoticed = false,
  });

  final List<FactLedgerResolvedCitation> citations;
  final String? leadLine;
  final bool showArchiveNoticed;

  static const Key sectionKey = Key('view_source_proof_section');
  static const Key toggleKey = Key('view_source_proof_toggle');
  static const Key expandedKey = Key('view_source_proof_expanded');

  @override
  State<ViewSourceProofSection> createState() => _ViewSourceProofSectionState();
}

class _ViewSourceProofSectionState extends State<ViewSourceProofSection> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.citations.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final lead =
        widget.leadLine ??
        EvidenceTrustCopy.supportedByEntries(widget.citations.length);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      height: 1.4,
    );
    final snippetStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      fontStyle: FontStyle.italic,
      height: 1.45,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    );

    return Column(
      key: ViewSourceProofSection.sectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showArchiveNoticed) ...[
          Text(EvidenceTrustCopy.archiveNoticed, style: labelStyle),
          const SizedBox(height: 4),
        ],
        Text(lead, style: muted),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: ViewSourceProofSection.toggleKey,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.textMuted,
              textStyle: muted?.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded
                  ? EvidenceTrustCopy.hideSourceProof
                  : EvidenceTrustCopy.viewSourceProof,
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          Column(
            key: ViewSourceProofSection.expandedKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.citations.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                Text(EvidenceTrustCopy.yourWordsLabel, style: labelStyle),
                const SizedBox(height: 2),
                Text(
                  '"${widget.citations[i].quote}"',
                  key: Key('view_source_proof_snippet_$i'),
                  style: snippetStyle,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
