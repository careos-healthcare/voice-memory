import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/verified_source_proof_sheet.dart';
import 'package:flutter/material.dart';

/// Subtle one-tap affordance that opens the verified source-proof sheet.
///
/// This is the public name for the control every pattern, belief-change, and
/// insight surface should use. It is a thin wrapper around
/// [VerifiedSourceProofLink]: same evidence, same sheet, same 48dp target.
/// Cards that already carry `ViewSourceProofSection` get this automatically.
///
/// Renders nothing when [evidence] is empty. An affordance that promised proof
/// it cannot open would be worse than no affordance.
class EvidenceTap extends StatelessWidget {
  const EvidenceTap({
    required this.evidence,
    super.key,
    this.claimContext,
    this.onOpenEntry,
    this.showCount = true,
  });

  /// Verifies [lines] first so the tap and the sheet describe the same quotes.
  factory EvidenceTap.fromLines({
    required List<InsightEvidenceLine> lines,
    Key? key,
    String? claimContext,
    ValueChanged<String>? onOpenEntry,
    bool showCount = true,
  }) => EvidenceTap(
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

  static const Key tapKey = Key('evidence_tap');
  static const double minTapTarget = VerifiedSourceProofLink.minTapTarget;

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) return const SizedBox.shrink();

    return KeyedSubtree(
      key: tapKey,
      child: VerifiedSourceProofLink(
        evidence: evidence,
        claimContext: claimContext,
        onOpenEntry: onOpenEntry,
        showCount: showCount,
      ),
    );
  }
}
