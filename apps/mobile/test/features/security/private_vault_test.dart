import 'dart:io';
import 'dart:math';

import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/features/security/biometric_auth_service.dart';
import 'package:archiveme_mobile/features/security/privacy_shield.dart';
import 'package:archiveme_mobile/features/security/private_vault_gate.dart';
import 'package:archiveme_mobile/features/security/vault_key_manager.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/security/app_lock_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(PrivateVaultGate.lock);

  test('master key stays in the keystore and payloads round-trip', () async {
    final store = MemoryAppLockStore();
    final manager = VaultKeyManager(store: store, random: Random(4));
    final first = await manager.masterKey();
    expect(await manager.masterKey(), first);
    expect(store.values[VaultKeyManager.masterKeyName], isNotEmpty);

    final salt = List<int>.generate(16, (index) => index);
    final derived = await manager.derivePayloadKey(
      passphrase: 'secret',
      salt: salt,
    );
    expect(
      await manager.derivePayloadKey(passphrase: 'secret', salt: salt),
      derived,
    );
    expect(
      await manager.derivePayloadKey(passphrase: 'other', salt: salt),
      isNot(derived),
    );

    final sealed = await manager.sealPayload(
      plaintext: 'Met Ada',
      passphrase: 'secret',
    );
    expect(
      await manager.openPayload(envelope: sealed, passphrase: 'secret'),
      'Met Ada',
    );
    expect(
      () => manager.openPayload(envelope: sealed, passphrase: 'nope'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );

    final argon = await manager.sealPayload(
      plaintext: 'quiet note',
      passphrase: 'secret',
      kdf: VaultKdf.argon2,
    );
    expect(
      await manager.openPayload(envelope: argon, passphrase: 'secret'),
      'quiet note',
    );
  });

  test('hidden moments stay out of search and the heatmap', () async {
    final directory = await Directory.systemTemp.createTemp('private-vault');
    final app = await openTestAppSqliteDatabase(
      filePath: '${directory.path}/archive.db',
    );
    addTearDown(() async {
      await app.close();
      AppSqliteDatabase.resetForTest();
    });
    final db = app.database;
    await _moment(db, 'visible', 'Walk in Banstead');
    await _moment(db, 'secret', 'A private note');
    await PrivateVaultGate.hide(db, 'secret');

    final hidden = await TimelineHeatmapStore.load(db);
    expect(hidden.map((entry) => entry.id), ['visible']);
    final clause = await PrivateVaultGate.andSql(db, 'je');
    final searched = await db.rawQuery(
      'SELECT id FROM journal_entries je WHERE je.deleted_at IS NULL $clause',
    );
    expect(searched.map((row) => row['id']), ['visible']);

    PrivateVaultGate.unlock();
    final opened = await TimelineHeatmapStore.load(db);
    expect(opened.map((entry) => entry.id).toSet(), {'visible', 'secret'});
  });

  testWidgets('the shield covers the switcher until biometrics succeed', (
    tester,
  ) async {
    final prompt = _Prompt(allow: true);
    final auth = BiometricAuthService(authenticator: prompt);
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyShield(
          auth: auth,
          child: const Text('Archive'),
        ),
      ),
    );
    expect(find.byKey(const Key('privacy_shield')), findsOneWidget);

    await tester.pump();
    await tester.pump();
    expect(find.text('Archive'), findsOneWidget);
    expect(find.byKey(const Key('privacy_shield')), findsNothing);
    expect(PrivateVaultGate.unlocked, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy_shield')), findsOneWidget);
    expect(PrivateVaultGate.unlocked, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('privacy_shield')), findsNothing);
    expect(prompt.calls, greaterThan(1));
  });

  testWidgets('Move to Private Vault is on the entry card', (tester) async {
    var moved = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveEntryCardHost(
            onMove: () => moved += 1,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('move_to_private_vault')));
    expect(moved, 1);
    expect(find.text('Move to Private Vault'), findsOneWidget);
  });
}

Future<void> _moment(Database db, String id, String transcript) {
  return db.insert('journal_entries', {
    'id': id,
    'created_at': 1,
    'updated_at': 1,
    'is_archived': 0,
    'transcript': transcript,
    'has_verified_proof': 0,
    'payload_json': '{}',
  });
}

class _Prompt implements BiometricAuthenticator {
  _Prompt({required this.allow});

  final bool allow;
  int calls = 0;

  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    calls += 1;
    expect(reason, BiometricAuthService.unlockReason);
    return allow;
  }
}

class ArchiveEntryCardHost extends StatelessWidget {
  const ArchiveEntryCardHost({required this.onMove, super.key});

  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return ArchiveEntryCard(
      entry: JournalEntry(
        id: 'moment-1',
        createdAt: DateTime.utc(2026, 9, 23),
        transcript: 'A saved moment',
        durationSeconds: 0,
        reflection: const Reflection(
          mood: 'calm',
          emotionalIntensity: 1,
          recurringThemes: ['focus'],
          exactLanguagePattern: 'pattern',
          concreteObservation: 'observation',
          repeatedSignal: 'signal',
        ),
      ),
      onTap: () {},
      onMoveToPrivateVault: onMove,
    );
  }
}
