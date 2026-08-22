import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_calculator.dart';
import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_models.dart';
import 'package:archiveme_mobile/features/evidence_artifact/views/evidence_proof_artifact_view.dart';
import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_builder.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_models.dart';
import 'package:flutter/material.dart';

/// Opens the interactive Evidence Proof Artifact screen.
Future<void> openEvidenceProofArtifact(
  BuildContext context, {
  required EvidenceProofArtifact artifact,
  bool openShareOnLaunch = false,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => EvidenceProofArtifactView(
        artifact: artifact,
        openShareOnLaunch: openShareOnLaunch,
      ),
    ),
  );
}

Future<void> openEvidenceProofForInsight(
  BuildContext context, {
  required Insight insight,
  bool openShareOnLaunch = false,
}) {
  return openEvidenceProofArtifact(
    context,
    artifact: EvidenceProofCalculator.fromInsight(insight),
    openShareOnLaunch: openShareOnLaunch,
  );
}

Future<void> openEvidenceProofForTrail(
  BuildContext context, {
  required EvidenceTrailPayload payload,
  bool openShareOnLaunch = false,
}) {
  return openEvidenceProofArtifact(
    context,
    artifact: EvidenceProofCalculator.fromEvidenceTrail(payload),
    openShareOnLaunch: openShareOnLaunch,
  );
}

Future<void> openEvidenceProofForArchiveV1(
  BuildContext context, {
  required ArchiveV1View view,
  bool openShareOnLaunch = false,
}) {
  final payload = buildEvidenceTrailForArchiveV1(view);
  if (payload == null) return Future.value();
  return openEvidenceProofForTrail(
    context,
    payload: payload,
    openShareOnLaunch: openShareOnLaunch,
  );
}