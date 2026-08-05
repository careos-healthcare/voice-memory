import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_display_gate.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_scope_provider.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/user_content_safety.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/account_namespace.dart';

/// Proves B2: switching the active account namespace actually fires the
/// proof/correction cache invalidation this task requires, for real — not
/// just that the underlying cache/store mechanisms exist (they mostly did
/// already; see `ArchiveCorrectionStore.switchArchive` and
/// `ProofAdmissionCache.invalidateArchive`/`invalidateAll`), but that
/// `AppServices._switchToNamespace` actually calls them.
int _uniqueSuffixCounter = 0;
String _uniqueSuffix() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_uniqueSuffixCounter++}';

Future<AccountNamespace> _resetForFreshAccount(String label) async {
  final suffix = _uniqueSuffix();
  final namespace = AccountNamespace.forUserId('$label-$suffix');
  await AppServices.resetForTest(
    journalPath:
        '${Directory.systemTemp.path}/vm_proof_scope_switch_journal_$suffix.json',
    skipRevenueCat: true,
    namespace: namespace,
  );
  return namespace;
}

/// Mirrors what `archive_me_startup.dart` does once at cold start: point
/// `ArchiveCorrectionStore` at the namespace `AppServices.resetForTest` just
/// opened. `AppServices.resetForTest` itself deliberately does not do this
/// (see its doc comment) so this fixture does it explicitly, matching
/// production startup.
Future<void> _seedArchiveCorrectionStoreForActiveNamespace() async {
  ArchiveCorrectionStore.instance.configure(AppServices.instance.prefs);
  await ArchiveCorrectionStore.instance.switchArchive(
    const AppServicesProofScopeProvider().activeArchiveScope,
  );
}

VerifiedProof _admittedProof({
  required String archiveScope,
  required String ownerScope,
  String entryId = 'entry-1',
  String transcript = 'I said yes again before checking my calendar.',
  String quote = 'said yes again',
  String observation = 'You agreed before checking your calendar.',
}) {
  final service = CanonicalProofAdmissionService();
  final result = service.admit(
    raw: RawModelResponse(
      payload: {
        'reflection': {
          'mood': 'neutral',
          'emotionalIntensity': 1,
          'recurringThemes': const ['capacity'],
          'exactLanguagePattern': quote,
          'concreteObservation': observation,
        },
      },
      receivedAt: DateTime.utc(2026, 7, 2),
    ),
    sourceEntries: [
      ProofSourceEntry(
        entryId: entryId,
        archiveScope: archiveScope,
        ownerScope: ownerScope,
        transcript: transcript,
        transcriptRevision: UserContentSafety.privacyHash(transcript),
        createdAt: DateTime.utc(2026, 7, 1),
        sourceType: ProofSourceType.userVoiceTranscript,
      ),
    ],
    activeArchiveScope: archiveScope,
    activeOwnerScope: ownerScope,
    primarySourceEntryId: entryId,
  );
  expect(result, isA<ProofAdmitted>());
  return (result as ProofAdmitted).proof;
}

JournalEntry _entry({
  required String id,
  required String transcript,
  VerifiedProof? proof,
}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7, 1),
  transcript: transcript,
  durationSeconds: 12,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: 'said yes again',
    concreteObservation: 'You agreed before checking your calendar.',
    repeatedSignal: '',
  ),
  verifiedProof: proof,
);

void main() {
  setUp(ArchiveCorrectionStore.resetForTest);
  tearDown(ArchiveCorrectionStore.resetForTest);

  test(
    'AppServicesProofScopeProvider derives distinct scopes per namespace, '
    'and keeps the legacy guest literals for backward compatibility',
    () async {
      final namespaceA = await _resetForFreshAccount('scope-account-a');
      const provider = AppServicesProofScopeProvider();
      final ownerScopeA = provider.activeOwnerScope;
      final archiveScopeA = provider.activeArchiveScope;
      expect(ownerScopeA, isNot('local_owner_v1'));
      expect(archiveScopeA, isNot('local_archive_v1'));

      await AppServices.switchNamespaceForTest(AccountNamespace.guest);
      expect(provider.activeOwnerScope, 'local_owner_v1');
      expect(provider.activeArchiveScope, 'local_archive_v1');

      final namespaceB = AccountNamespace.forUserId(
        'scope-account-b-${_uniqueSuffix()}',
      );
      await AppServices.switchNamespaceForTest(namespaceB);
      expect(
        provider.activeOwnerScope,
        isNot(ownerScopeA),
        reason: 'two different accounts must never resolve the same scope',
      );
      expect(provider.activeArchiveScope, isNot(archiveScopeA));

      await AppServices.switchNamespaceForTest(namespaceA);
      expect(
        provider.activeOwnerScope,
        ownerScopeA,
        reason: 'switching back must resolve the same scope as before',
      );
    },
  );

  test('switching accounts re-points ArchiveCorrectionStore at the new '
      'namespace, so a correction recorded after the switch is never '
      'written into the outgoing account\'s prefs file', () async {
    final namespaceA = await _resetForFreshAccount('correction-account-a');
    await _seedArchiveCorrectionStoreForActiveNamespace();
    const provider = AppServicesProofScopeProvider();
    final scopeA = provider.activeArchiveScope;

    final proofA = _admittedProof(
      archiveScope: scopeA,
      ownerScope: provider.activeOwnerScope,
    );
    await ArchiveCorrectionStore.instance.recordForProof(
      proof: proofA,
      choice: ArchiveCorrectionChoice.exactlyRight,
      sourceSurface: 'test',
    );
    expect(ArchiveCorrectionStore.instance.records, hasLength(1));
    expect(
      ArchiveCorrectionStore.instance.activeArchiveScope,
      scopeA,
      reason: 'seeded to reflect the namespace active before any switch',
    );

    final namespaceB = AccountNamespace.forUserId(
      'correction-account-b-${_uniqueSuffix()}',
    );
    await AppServices.switchNamespaceForTest(namespaceB);
    final scopeB = provider.activeArchiveScope;
    expect(scopeB, isNot(scopeA));

    expect(
      ArchiveCorrectionStore.instance.activeArchiveScope,
      scopeB,
      reason:
          'the switch must have called switchArchive with the new '
          'namespace\'s own scope — this is the actual B2 wiring under '
          'test, not just the pre-existing switchArchive method',
    );
    expect(
      ArchiveCorrectionStore.instance.records,
      isEmpty,
      reason:
          "account A's in-memory correction must not still answer for "
          'account B',
    );

    // Record a correction for a DIFFERENT proof while B is active, so a
    // subsequent decide() under A cannot accidentally match on it.
    final proofB = _admittedProof(
      archiveScope: scopeB,
      ownerScope: provider.activeOwnerScope,
      entryId: 'entry-b',
      transcript: 'I skipped the gym again after promising myself I would go.',
      quote: 'skipped the gym again',
      observation: 'You skipped the gym after promising yourself you would go.',
    );
    await ArchiveCorrectionStore.instance.recordForProof(
      proof: proofB,
      choice: ArchiveCorrectionChoice.wrong,
      sourceSurface: 'test',
    );
    expect(ArchiveCorrectionStore.instance.records, hasLength(1));

    final decisionUnderB = ArchiveCorrectionStore.instance.decide(
      ProofCorrectionQuery(
        archiveScope: scopeB,
        proofFingerprint: proofA.proofFingerprint,
        semanticFramingFingerprint: proofA.semanticFramingFingerprint,
        wordingFingerprint: proofA.wordingFingerprint,
        evidenceSourceIds: const {},
      ),
    );
    expect(
      decisionUnderB.suppressed,
      isFalse,
      reason: "account A's correction must not influence account B",
    );

    // Switching back to A must restore exactly A's correction (persisted
    // under A's own prefs file, untouched by the write B just made — the
    // real risk this reconciliation exists to prevent is
    // `ArchiveCorrectionStore` staying configured against A's prefs after
    // the switch and silently writing B's correction into A's file).
    await AppServices.switchNamespaceForTest(namespaceA);
    expect(
      ArchiveCorrectionStore.instance.activeArchiveScope,
      scopeA,
      reason: 'switching back must re-point the store at A\'s own scope',
    );
    expect(
      ArchiveCorrectionStore.instance.records,
      hasLength(1),
      reason: "account A's own correction must have survived intact",
    );
    final decisionUnderA = ArchiveCorrectionStore.instance.decide(
      ProofCorrectionQuery(
        archiveScope: scopeA,
        proofFingerprint: proofA.proofFingerprint,
        semanticFramingFingerprint: proofA.semanticFramingFingerprint,
        wordingFingerprint: proofA.wordingFingerprint,
        evidenceSourceIds: const {},
      ),
    );
    expect(
      decisionUnderA.suppressed,
      isFalse,
      reason: '"exactlyRight" never suppresses',
    );
    final decisionForBUnderA = ArchiveCorrectionStore.instance.decide(
      ProofCorrectionQuery(
        archiveScope: scopeA,
        proofFingerprint: proofB.proofFingerprint,
        semanticFramingFingerprint: proofB.semanticFramingFingerprint,
        wordingFingerprint: proofB.wordingFingerprint,
        evidenceSourceIds: const {},
      ),
    );
    expect(
      decisionForBUnderA.suppressed,
      isFalse,
      reason:
          "account B's 'wrong' correction must not leak into account A "
          "as a suppression A never made",
    );
  });

  test('switching accounts drops the shared proof-display cache', () async {
    await _resetForFreshAccount('cache-account-a');
    const provider = AppServicesProofScopeProvider();
    final gate = ProofDisplayGate.forCurrentAccount(scopeProvider: provider);

    gate.sourceFor(_entry(id: 'e1', transcript: 'A private moment.'));
    expect(
      ProofDisplayGate.debugSharedCacheRevisionCount,
      greaterThan(0),
      reason: 'the fixture itself must have populated the shared cache',
    );

    final namespaceB = AccountNamespace.forUserId(
      'cache-account-b-${_uniqueSuffix()}',
    );
    await AppServices.switchNamespaceForTest(namespaceB);

    expect(
      ProofDisplayGate.debugSharedCacheRevisionCount,
      0,
      reason:
          'ProofDisplayGate.invalidateForAccountSwitch must have been '
          'called by the namespace switch itself',
    );
  });

  test('switching back to the already-active namespace does not needlessly '
      'invalidate the correction store (switchArchive no-ops on an unchanged '
      'scope)', () async {
    final namespaceA = await _resetForFreshAccount('noop-account-a');
    await _seedArchiveCorrectionStoreForActiveNamespace();
    const provider = AppServicesProofScopeProvider();

    final proof = _admittedProof(
      archiveScope: provider.activeArchiveScope,
      ownerScope: provider.activeOwnerScope,
    );
    await ArchiveCorrectionStore.instance.recordForProof(
      proof: proof,
      choice: ArchiveCorrectionChoice.exactlyRight,
      sourceSurface: 'test',
    );

    await AppServices.switchNamespaceForTest(namespaceA);

    expect(
      ArchiveCorrectionStore.instance.records,
      hasLength(1),
      reason: 'switching to the same namespace must not drop its records',
    );
  });
}
