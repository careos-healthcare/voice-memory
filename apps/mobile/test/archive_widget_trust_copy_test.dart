import 'package:archiveme_mobile/features/archive_changes/archive_changes_adapter.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_section.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/archive_changes_section.dart';
import 'package:archiveme_mobile/widgets/archive/archive_verified_changes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _archiveScope = 'local_archive_v1';
const _ownerScope = 'local_owner_v1';

VerifiedProof _admittedProof({
  required String entryId,
  required String transcript,
}) {
  final transcriptRevision = UserContentSafety.privacyHash(transcript);
  final service = CanonicalProofAdmissionService(
    clock: () => DateTime.utc(2026, 7, 2),
  );
  final result = service.admit(
    raw: RawModelResponse(
      payload: {
        'reflection': {
          'mood': 'neutral',
          'emotionalIntensity': 2,
          'recurringThemes': const ['capacity'],
          'exactLanguagePattern': 'said yes again',
          'concreteObservation': 'You agreed before checking your calendar.',
          'repeatedSignal': 'This always happens.',
          'nextSmallAction': 'Say no next time.',
        },
      },
      receivedAt: DateTime.utc(2026, 7, 2),
    ),
    sourceEntries: [
      ProofSourceEntry(
        entryId: entryId,
        archiveScope: _archiveScope,
        ownerScope: _ownerScope,
        transcript: transcript,
        transcriptRevision: transcriptRevision,
        createdAt: DateTime.utc(2026, 7),
        sourceType: ProofSourceType.userVoiceTranscript,
        remoteProcessingConsented: true,
      ),
    ],
    activeArchiveScope: _archiveScope,
    activeOwnerScope: _ownerScope,
    primarySourceEntryId: entryId,
  );
  return (result as ProofAdmitted).proof;
}

JournalEntry _entry({
  required String id,
  required String transcript,
  required VerifiedProof proof,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
    verifiedProof: proof,
  );
}

void main() {
  group('Archive widget trust copy', () {
    testWidgets('verified changes section hedges archive read vs user words', (
      tester,
    ) async {
      const transcript = 'I said yes again before checking my calendar.';
      final proof = _admittedProof(entryId: 'proof-entry', transcript: transcript);
      final entry = _entry(id: 'proof-entry', transcript: transcript, proof: proof);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveVerifiedChangesSection.fromEntries(entries: [entry]),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(ArchiveVerifiedChangesSection.heading),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveVerifiedChangesSection.subheading),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveVerifiedChangesSection.archiveReadLabel),
        findsOneWidget,
      );
      expect(find.text(EvidenceTrustCopy.viewSourceProof), findsOneWidget);
      await tester.tap(find.byKey(ViewSourceProofSection.toggleKey));
      await tester.pumpAndSettle();
      expect(
        find.text(EvidenceTrustCopy.transcriptExcerptLabel),
        findsWidgets,
      );
      expect(
        find.text(ArchiveVerifiedChangesSection.correctionHint),
        findsOneWidget,
      );
      expect(find.textContaining('confirmed'), findsNothing);
    });

    testWidgets('changes section shows correction affordance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveChangesSection(
            previewSnapshot: ArchiveChangesSnapshot(
              entries: const [],
              timeline: const [],
              eligible: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(ConsumerUiCopy.changesScreenLead), findsOneWidget);
      expect(
        find.text(ConsumerUiCopy.changesSectionCorrectionHint),
        findsOneWidget,
      );
    });
  });
}
