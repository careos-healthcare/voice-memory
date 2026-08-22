import 'dart:io';

import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

int _uniqueSuffixCounter = 0;
String _uniqueSuffix() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_uniqueSuffixCounter++}';

Future<MobilePrefsStore> _openPrefs([String? label]) => MobilePrefsStore.open(
  '${Directory.systemTemp.path}/vm_consent_prefs_'
  '${label ?? _uniqueSuffix()}.json',
);

Future<void> _writeRawConsent(
  MobilePrefsStore prefs,
  Map<String, dynamic> json,
) async {
  await prefs.writeJsonMap(RemoteProcessingConsentStore.prefsKey, json);
}

void main() {
  test(
    'a brand-new namespace defaults to consent false, with no history',
    () async {
      final prefs = await _openPrefs();
      final store = RemoteProcessingConsentStore(prefs);

      final state = await store.current();

      expect(state.consented, isFalse);
      expect(state.grantedPurposes, isEmpty);
      expect(state.consentedAt, isNull);
      expect(state.permittedCategories, isEmpty);
      expect(await store.isConsentedNow(), isFalse);
      expect(
        await store.isPurposeGrantedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isFalse,
      );
    },
  );

  test('granting persists typed purposes with audit metadata', () async {
    final prefs = await _openPrefs();
    final store = RemoteProcessingConsentStore(prefs);
    final now = DateTime.utc(2026, 8, 5, 12);

    final granted = await store.grant(now: now);

    expect(granted.consented, isTrue);
    expect(granted.consentedAt, now);
    expect(granted.policyVersion, RemoteProcessingConsentStore.currentPolicyVersion);
    expect(
      granted.grantedPurposes,
      RemoteProcessingPurposeStorage.onboardingGrant,
    );
    expect(
      await store.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteTranscription,
      ),
      isTrue,
    );
    expect(
      await store.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteReflection,
      ),
      isTrue,
    );
  });

  test('partial grant allows only the granted purpose', () async {
    final prefs = await _openPrefs();
    final store = RemoteProcessingConsentStore(prefs);

    await store.grant(
      purposes: {RemoteProcessingPurpose.remoteTranscription},
    );

    expect(
      await store.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteTranscription,
      ),
      isTrue,
    );
    expect(
      await store.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteReflection,
      ),
      isFalse,
    );
  });

  test(
    'withdrawing clears all purposes and records revokedAt immediately',
    () async {
      final prefs = await _openPrefs();
      final store = RemoteProcessingConsentStore(prefs);
      await store.grant(now: DateTime.utc(2026, 8, 5));

      final withdrawn = await store.withdraw(now: DateTime.utc(2026, 8, 6));

      expect(withdrawn.consented, isFalse);
      expect(withdrawn.grantedPurposes, isEmpty);
      expect(withdrawn.revokedAt, DateTime.utc(2026, 8, 6));
      expect(await store.isConsentedNow(), isFalse);
      expect(
        await store.isPurposeGrantedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isFalse,
      );
    },
  );

  test('grantPurpose merges with existing purposes', () async {
    final prefs = await _openPrefs();
    final store = RemoteProcessingConsentStore(prefs);
    await store.grant(
      purposes: {RemoteProcessingPurpose.remoteTranscription},
    );

    await store.grantPurpose(RemoteProcessingPurpose.remoteReflection);

    expect(
      await store.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteReflection,
      ),
      isTrue,
    );
  });

  test('legacy v1 categories migrate to typed purposes', () async {
    final prefs = await _openPrefs();
    await _writeRawConsent(prefs, {
      'consented': true,
      'permittedCategories': ['transcription'],
      'policyVersion': 1,
      'consentedAt': '2026-08-01T12:00:00.000Z',
    });
    final store = RemoteProcessingConsentStore(prefs);

    final state = await store.current();

    expect(state.grantedPurposes, {RemoteProcessingPurpose.remoteTranscription});
    expect(
      await store.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteReflection,
      ),
      isFalse,
    );
  });

  test('ambiguous legacy consented=true with empty categories fails closed',
      () async {
    final prefs = await _openPrefs();
    await _writeRawConsent(prefs, {
      'consented': true,
      'permittedCategories': [],
      'policyVersion': 1,
    });
    final store = RemoteProcessingConsentStore(prefs);

    final state = await store.current();

    expect(state.grantedPurposes, isEmpty);
    expect(
      await store.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteTranscription,
      ),
      isFalse,
    );
  });

  test('policy version is preserved on withdraw and restored on re-grant',
      () async {
    final prefs = await _openPrefs();
    final store = RemoteProcessingConsentStore(prefs);
    await store.grant(policyVersion: 2);
    await store.withdraw();
    final reGranted = await store.grant();

    expect(reGranted.policyVersion, RemoteProcessingConsentStore.currentPolicyVersion);
  });

  test('restart persistence: a fresh store instance reads back typed purposes',
      () async {
    final path =
        '${Directory.systemTemp.path}/vm_consent_prefs_restart_${_uniqueSuffix()}.json';
    final first = RemoteProcessingConsentStore(
      await MobilePrefsStore.open(path),
    );
    await first.grant(
      purposes: {RemoteProcessingPurpose.remoteReflection},
      now: DateTime.utc(2026, 8, 5),
    );

    final second = RemoteProcessingConsentStore(
      await MobilePrefsStore.open(path),
    );
    final reopened = await second.current();

    expect(reopened.grantedPurposes, {RemoteProcessingPurpose.remoteReflection});
    expect(reopened.consentedAt, DateTime.utc(2026, 8, 5));
  });

  test('two namespaces never see each other\'s decision', () async {
    final guestPrefs = await _openPrefs('guest');
    final accountPrefs = await _openPrefs('account');
    final guestStore = RemoteProcessingConsentStore(guestPrefs);
    final accountStore = RemoteProcessingConsentStore(accountPrefs);

    await guestStore.grant();

    expect(await guestStore.isConsentedNow(), isTrue);
    expect(await accountStore.isConsentedNow(), isFalse);
  });

  test('a read error is treated as not consented, not as a crash', () async {
    final path =
        '${Directory.systemTemp.path}/vm_consent_prefs_garbage_${_uniqueSuffix()}.json';
    await File(
      path,
    ).writeAsString('{"remote_processing_consent_v1": "not-a-map"}');
    final store = RemoteProcessingConsentStore(
      await MobilePrefsStore.open(path),
    );

    final state = await store.current();
    expect(state.consented, isFalse);
    expect(
      await store.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteTranscription,
      ),
      isFalse,
    );
  });
}
