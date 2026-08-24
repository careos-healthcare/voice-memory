import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/verified_source_proof_sheet.dart';
import 'package:flutter/material.dart';

/// Subtle one-tap affordance that opens the verified source-proof sheet.
///
/// Public name for the control every pattern, belief-change, and insight
/// surface should use. Thin wrapper around [VerifiedSourceProofLink]: same
/// evidence, same sheet, same 48dp target. Cards that already carry
/// `ViewSourceProofSection` get this automatically.
///
/// The label is "How we know" (source-data sense). Renders nothing when
/// [evidence] is empty — an affordance that promised proof it cannot open
/// would be worse than no affordance. Never invents a quote.
class EvidenceTrailButton extends StatelessWidget {
  const EvidenceTrailButton({
    required this.evidence,
    super.key,
    this.claimContext,
    this.onOpenEntry,
    this.showCount = true,
  });

  /// Verifies [lines] first so the tap and the sheet describe the same quotes.
  factory EvidenceTrailButton.fromLines({
    required List<InsightEvidenceLine> lines,
    Key? key,
    String? claimContext,
    ValueChanged<String>? onOpenEntry,
    bool showCount = true,
  }) => EvidenceTrailButton(
    evidence: VerifiedSourceProofSheet.verifiedFrom(lines),
    key: key,
    claimContext: claimContext,
    onOpenEntry: onOpenEntry,
    showCount: showCount,
  );

  final List<VerbatimEvidence> evidence;
  final String? claimContext;
  final ValueChanged<String>? onOpenEntry;
  final bool showCount;

  static const Key buttonKey = Key('evidence_trail_button');

  /// Backward-compatible key used by the EvidenceTap alias and existing tests.
  static const Key tapKey = Key('evidence_tap');

  static const double minTapTarget = VerifiedSourceProofLink.minTapTarget;

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) return const SizedBox.shrink();

    return KeyedSubtree(
      key: buttonKey,
      child: KeyedSubtree(
        key: tapKey,
        child: VerifiedSourceProofLink(
          evidence: evidence,
          claimContext: claimContext,
          onOpenEntry: onOpenEntry,
          showCount: showCount,
        ),
      ),
    );
  }
}
