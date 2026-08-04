import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_transport.dart';
import 'package:voicememory_mobile/api/journal_sync_api_client.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/features/journal/sync/saved_moment_sync_key_store.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_screen.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_service.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';

import 'support/accessibility_matrix.dart';

final class _UiRecoveryApi extends JournalSyncApiClient {
  _UiRecoveryApi() : super(ApiTransport(baseUrl: 'https://example.test'));
  Map<String, dynamic>? envelope;

  @override
  Future<Map<String, dynamic>> syncRecoveryStatus() async => {
    'enabled': envelope != null,
  };

  @override
  Future<Map<String, dynamic>> syncRecoveryFetch() async => {
    'envelope': envelope,
  };

  @override
  Future<Map<String, dynamic>> syncRecoveryUpsert(
    Map<String, dynamic> value,
  ) async {
    envelope = value;
    return {'ok': true};
  }

  @override
  Future<void> syncRecoveryDelete() async {
    envelope = null;
  }
}

void main() {
  testWidgets('setup requires exact re-entry and then hides code permanently', (
    tester,
  ) async {
    final api = _UiRecoveryApi();
    final identity = LocalArchiveIdentity(
      archiveId: 'archive-a',
      ownerKind: LocalArchiveOwnerKind.authenticated,
      authenticatedSubjectId: 'account-a',
      ownershipState: LocalArchiveOwnershipState.active,
    );
    final service = SyncRecoveryService(
      api: api,
      keyStore: SavedMomentSyncKeyStore(InMemorySecureStorageService()),
      identityProvider: () => identity,
    );
    await tester.pumpWidget(
      MaterialApp(home: SyncRecoveryScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsNothing);
    expect(find.textContaining('shown once'), findsOneWidget);
    expect(find.textContaining('never included'), findsOneWidget);
    expect(find.textContaining('Status: Recovery not set up'), findsOneWidget);
    expect(find.textContaining('signed-in account'), findsOneWidget);
    expect(find.textContaining('Store the code offline'), findsOneWidget);
    expect(find.textContaining('permanently unrecoverable'), findsOneWidget);
    expect(find.byKey(const Key('sync_recovery_setup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sync_recovery_setup')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.byKey(const Key('sync_recovery_one_time_code')),
      findsOneWidget,
    );
    expect(find.text('Copy recovery code'), findsOneWidget);
    expect(find.text('Print recovery instructions'), findsOneWidget);
    final code = tester
        .widget<SelectableText>(
          find.byKey(const Key('sync_recovery_one_time_code')),
        )
        .data!;

    final wrongLastCharacter = code.endsWith('A')
        ? '${code.substring(0, code.length - 1)}B'
        : '${code.substring(0, code.length - 1)}A';
    await tester.enterText(
      find.byKey(const Key('sync_recovery_confirmation_input')),
      wrongLastCharacter,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('sync_recovery_confirm_saved')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('sync_recovery_confirm_saved')));
    await tester.pump();
    expect(find.textContaining('Confirmation does not match'), findsOneWidget);
    expect(
      find.byKey(const Key('sync_recovery_one_time_code')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('sync_recovery_confirmation_input')),
      code,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('sync_recovery_confirm_saved')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('sync_recovery_confirm_saved')));
    await tester.pump();
    expect(find.byKey(const Key('sync_recovery_one_time_code')), findsNothing);
    expect(find.textContaining('cannot be displayed again'), findsOneWidget);
    expect(find.text('Replace recovery code'), findsOneWidget);
    expect(find.text('Disable recovery'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SyncRecoveryScreen(
          key: const ValueKey('reopened-recovery-screen'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Status: Recovery enabled'), findsOneWidget);
    expect(find.byKey(const Key('sync_recovery_one_time_code')), findsNothing);
  });

  testWidgets('disable warning requires confirmation and recommends export', (
    tester,
  ) async {
    final api = _UiRecoveryApi()..envelope = {'existing': true};
    final identity = LocalArchiveIdentity(
      archiveId: 'archive-a',
      ownerKind: LocalArchiveOwnerKind.authenticated,
      authenticatedSubjectId: 'account-a',
      ownershipState: LocalArchiveOwnershipState.active,
    );
    final service = SyncRecoveryService(
      api: api,
      keyStore: SavedMomentSyncKeyStore(InMemorySecureStorageService()),
      identityProvider: () => identity,
    );
    await tester.pumpWidget(
      MaterialApp(home: SyncRecoveryScreen(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sync_recovery_disable')));
    await tester.pumpAndSettle();
    expect(find.text('Disable sync recovery?'), findsOneWidget);
    expect(find.textContaining('Export your archive first'), findsOneWidget);
    expect(find.textContaining('permanently impossible'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Disable recovery'),
      findsOneWidget,
    );
  });

  testWidgets('2x text preserves recovery order, keyboard, and 48dp targets', (
    tester,
  ) async {
    final identity = LocalArchiveIdentity(
      archiveId: 'archive-accessibility',
      ownerKind: LocalArchiveOwnerKind.authenticated,
      authenticatedSubjectId: 'account-accessibility',
      ownershipState: LocalArchiveOwnershipState.active,
    );
    final service = SyncRecoveryService(
      api: _UiRecoveryApi(),
      keyStore: SavedMomentSyncKeyStore(InMemorySecureStorageService()),
      identityProvider: () => identity,
    );
    final semantics = tester.ensureSemantics();
    await pumpUnderProfile(
      tester,
      const AccessibilityProfile(
        name: 'recovery 2x',
        size: Size(390, 1800),
        brightness: Brightness.light,
        textScale: 2,
      ),
      child: SyncRecoveryScreen(service: service),
    );

    expectNoOverflow(tester);
    expectTapTargets(tester, minimum: 48);
    final order = semanticReadingOrder(tester);
    expectAnnouncedBefore(
      order,
      'Optional recovery wraps',
      'Status: Recovery not set up',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expectTapTargets(tester, minimum: 48);
    expect(find.bySemanticsLabel('Set up recovery'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expectTapTargets(tester, minimum: 48);
    expect(find.bySemanticsLabel(RegExp('Recovery code')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(primaryFocus, isNotNull);
    semantics.dispose();
  });
}
