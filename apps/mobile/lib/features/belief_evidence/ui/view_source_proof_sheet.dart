import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Bottom sheet listing fact-ledger transcript excerpts for a cited read.
class ViewSourceProofSheet extends StatelessWidget {
  const ViewSourceProofSheet({
    required this.citations,
    super.key,
    this.claimContext,
  });

  final List<FactLedgerResolvedCitation> citations;
  final String? claimContext;

  static const Key sheetKey = Key('view_source_proof_sheet');

  static Future<void> show(
    BuildContext context, {
    required List<FactLedgerResolvedCitation> citations,
    String? claimContext,
  }) {
    if (citations.isEmpty) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ViewSourceProofSheet(
        citations: citations,
        claimContext: claimContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sorted = [...citations]
      ..sort((a, b) {
        final aDate = a.recordedAt;
        final bDate = b.recordedAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          key: ViewSourceProofSheet.sheetKey,
          color: AppColors.backgroundPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        EvidenceTrustCopy.viewSourceProof,
                        style: VoiceMemoryTypography.pageTitleStyle().copyWith(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
                  children: [
                    if (claimContext case final contextText?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          contextText,
                          style: VoiceMemoryTypography.bodyStyle(
                            color: AppColors.textSecondary,
                          ).copyWith(height: 1.45),
                        ),
                      ),
                    Text(
                      EvidenceTrustCopy.sheetLead,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textMuted,
                      ).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < sorted.length; i++)
                      _SourceExcerptCard(
                        citation: sorted[i],
                        index: i,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SourceExcerptCard extends StatelessWidget {
  const _SourceExcerptCard({
    required this.citation,
    required this.index,
  });

  final FactLedgerResolvedCitation citation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final muted = VoiceMemoryTypography.secondaryStyle(
      color: AppColors.textMuted,
    ).copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        key: Key('view_source_proof_excerpt_$index'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (citation.label case final label?)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(label, style: muted),
              ),
            if (citation.recordedAt case final recordedAt?)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  formatUserFacingDate(recordedAt),
                  style: muted,
                ),
              ),
            Text(
              EvidenceTrustCopy.transcriptExcerptLabel,
              style: muted.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              '"${citation.quote}"',
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
