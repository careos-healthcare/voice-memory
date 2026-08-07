import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

int _uniqueSuffixCounter = 0;
String _uniqueSuffix() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_uniqueSuffixCounter++}';

Future<MobilePrefsStore> _openPrefs([String? label]) => MobilePrefsStore.open(
  '${Directory.systemTemp.path}/vm_consent_prefs_'
  '${label ?? _uniqueSuffix()}.json',
);

void main() {
  test(
    'a brand-new namespace defaults to consent false, with no history',
    () async {
      final prefs = await _openPrefs();
      final store = RemoteProcessingConsentStore(prefs);

      final state = await store.current();

      expect(state.consented, isFalse);
      expect(state.consentedAt, isNull);
      expect(state.permittedCategories, isEmpty);
      expect(await store.isConsentedNow(), isFalse);
    },
  );

  test('granting persists an explicit opt-in with a timestamp', () async {
    final prefs = await _openPrefs();
    final store = RemoteProcessingConsentStore(prefs);
    final now = DateTime.utc(2026, 8, 5, 12);

    final granted = await store.grant(now: now);

    expect(granted.consented, isTrue);
    expect(granted.consentedAt, now);
    expect(granted.permittedCategories, isNotEmpty);
    expect(await store.isConsentedNow(), isTrue);
  });

  test(
    'withdrawing persists false and immediately reads back as unconsented',
    () async {
      final prefs = await _openPrefs();
      final store = RemoteProcessingConsentStore(prefs);
      await store.grant(now: DateTime.utc(2026, 8, 5));

      final withdrawn = await store.withdraw(now: DateTime.utc(2026, 8, 6));

      expect(withdrawn.consented, isFalse);
      expect(await store.isConsentedNow(), isFalse);
      expect(
        withdrawn.consentedAt,
        DateTime.utc(2026, 8, 5),
        reason: 'the last time consent was actually given is kept for history',
      );
    },
  );

  test('restart persistence: a fresh store instance over the same file reads '
      'back the same decision', () async {
    final path =
        '${Directory.systemTemp.path}/vm_consent_prefs_restart_${_uniqueSuffix()}.json';
    final first = RemoteProcessingConsentStore(
      await MobilePrefsStore.open(path),
    );
    await first.grant(now: DateTime.utc(2026, 8, 5));

    final second = RemoteProcessingConsentStore(
      await MobilePrefsStore.open(path),
    );
    final reopened = await second.current();

    expect(reopened.consented, isTrue);
    expect(reopened.consentedAt, DateTime.utc(2026, 8, 5));
  });

  test('two stores over two different prefs files (as two account namespaces '
      'would be, per Part A) never see each other\'s decision', () async {
    final guestPrefs = await _openPrefs('guest');
    final accountPrefs = await _openPrefs('account');
    final guestStore = RemoteProcessingConsentStore(guestPrefs);
    final accountStore = RemoteProcessingConsentStore(accountPrefs);

    await guestStore.grant();

    expect(await guestStore.isConsentedNow(), isTrue);
    expect(
      await accountStore.isConsentedNow(),
      isFalse,
      reason:
          'a different namespace must start at the real default, never '
          "inherit another namespace's opt-in",
    );
  });

  test('a read error is treated as not consented, not as a crash', () async {
    // A prefs file whose stored value is garbage for this key must fail
    // closed rather than throw out of a capture-time gate.
    final path =
        '${Directory.systemTemp.path}/vm_consent_prefs_garbage_${_uniqueSuffix()}.json';
    await File(
      path,
    ).writeAsString('{"remote_processing_consent_v1": "not-a-map"}');
    final store = RemoteProcessingConsentStore(
      await MobilePrefsStore.open(path),
    );

    // readJsonMap on a non-map value returns null upstream, so this reads as
    // "never decided" rather than throwing.
    final state = await store.current();
    expect(state.consented, isFalse);
  });
}
