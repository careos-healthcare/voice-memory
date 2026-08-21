import 'package:archiveme_mobile/features/proof_admission/proof_display_gate.dart';
import 'package:archiveme_mobile/features/proof_admission/verified_proof_view_model.dart' show VerifiedProofViewModel;
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/proof/proof_detail_sheet.dart';
import 'package:archiveme_mobile/widgets/proof/verified_proof_correction_controls.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The compact post-save proof card: one cautious statement, the exact evidence
/// behind it, how confident it is, and one way in to the full detail.
///
/// It renders a [VerifiedProofViewModel] and nothing else. It deliberately does
/// not recompute confidence or count references itself — those belong to the
/// admission pipeline, so the card cannot disagree with the receipt it displays.
class PostSaveBeliefInsight extends StatelessWidget {
  const PostSaveBeliefInsight({
    required this.entries, super.key,
    this.gate = const ProofDisplayGate(),
  });

  static const String proofDetailsCta = 'Proof details';
  static const String basisLabel = 'Because you said';

  final List<JournalEntry> entries;

  /// Re-verifies the stored proof against the archive as it is right now. A
  /// proof whose quoted transcript has since been edited, or whose entry has
  /// been archived, does not render at all.
  final ProofDisplayGate gate;

  @override
  Widget build(BuildContext context) {
    final verified = gate.latestVerified(entries);
    if (verified == null) return const SizedBox.shrink();

    final proof = verified.entry.verifiedProof!;
    final view = verified.view;
    final statement = view.statement.trim();
    if (statement.isEmpty) return const SizedBox.shrink();
    final evidence = view.supportingEvidence.firstOrNull;
    final corrections = VerifiedProofCorrectionControls(
      proof: proof,
      sourceSurface: 'post_save_belief',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: VoiceMemoryCards.standard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                BeliefProductCopy.postSavePossibleBelief,
                style: VoiceMemoryTypography.metadataStyle(
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '"$statement"',
                key: const Key('post_save_statement'),
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontSize: 20,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _row(BeliefProductCopy.postSaveConfidence, view.confidenceLabel),
              if (evidence != null) ...[
                const SizedBox(height: 6),
                _row(basisLabel, '“${evidence.quote}”', valueKey: 'quote'),
                const SizedBox(height: 6),
                _row(
                  BeliefProductCopy.postSaveBasedOn,
                  ProofDetailSheet.formatEvidenceDate(evidence.sourceDate),
                ),
              ],
            ],
          ),
        ),
        corrections,
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const Key('post_save_proof_details'),
          onPressed: () => ProofDetailSheet.show(
            context,
            proof: view,
            correctionControls: VerifiedProofCorrectionControls(
              proof: proof,
              sourceSurface: 'proof_detail',
            ),
          ),
          child: const Text(proofDetailsCta),
        ),
        OutlinedButton(
          onPressed: () => context.go('/record'),
          child: const Text(BeliefProductCopy.postSaveRecordAnother),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {String? valueKey}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 100,
        child: Text(label, style: VoiceMemoryTypography.metadataStyle()),
      ),
      Expanded(
        child: Text(
          value,
          key: valueKey == null ? null : Key('post_save_evidence_$valueKey'),
          style: VoiceMemoryTypography.bodyStyle(),
        ),
      ),
    ],
  );
}