import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/screens/delete_account_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_account_api_client.dart';
import 'support/test_storage_sandbox.dart';

/// Delete account is destructive and irreversible, so it must always require
/// an explicit confirmation step before the network call fires — see the
/// accessibility audit's "destructive confirmation dialogs" requirement.
///
/// NOTE: deliberately avoids `pumpAndSettle` (which never quiesces in this
/// app's widget-test harness) in favor of the fixed-duration `pump()` pattern
/// already used elsewhere, e.g. `account_auth_test.dart`.
void main() {
  late TestStorageSandbox sandbox;
  late FakeAccountApiClient fakeAccountApi;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    fakeAccountApi = FakeAccountApiClient();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
      networkOverrides: [
        accountApiClientProvider.overrideWithValue(fakeAccountApi),
      ],
    );
  });

  tearDown(() => sandbox.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeleteAccountScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpScreenWithRouter(WidgetTester tester) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    final router = GoRouter(
      initialLocation: '/delete-account',
      routes: [
        GoRoute(
          path: '/delete-account',
          builder: (context, state) => DeleteAccountScreen(
            accountDependencies: V1AccountDependencies.fromAppServices(),
          ),
        ),
        GoRoute(
          path: '/record',
          builder: (context, state) =>
              const Scaffold(body: Text('record destination')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        scaffoldMessengerKey: messengerKey,
        routerConfig: router,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openConfirmDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Delete account confirmation', () {
    testWidgets('shows a confirmation dialog before deleting', (tester) async {
      await pumpScreen(tester);

      expect(
        find.byKey(const Key('delete_account_confirm_dialog')),
        findsNothing,
      );

      await openConfirmDialog(tester);

      expect(
        find.byKey(const Key('delete_account_confirm_dialog')),
        findsOneWidget,
      );
      expect(find.text('Delete account permanently?'), findsOneWidget);
      expect(fakeAccountApi.deleteAccountCalls, 0);
    });

    testWidgets('cancelling the dialog does not start deletion', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openConfirmDialog(tester);

      await tester.tap(find.byKey(const Key('delete_account_confirm_cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('delete_account_confirm_dialog')),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Delete account'),
        findsOneWidget,
      );
      expect(fakeAccountApi.deleteAccountCalls, 0);
    });

    testWidgets('confirming dismisses the dialog and calls deleteAccount', (
      tester,
    ) async {
      // Fail the call deliberately: on success the screen calls
      // `context.go('/record')`, which needs a GoRouter this test's plain
      // `MaterialApp` doesn't provide. This test only asserts the
      // confirmation gate calls through to the API — not the post-success
      // navigation, which is exercised by the app's real router elsewhere.
      fakeAccountApi.deleteAccountFailure = const ApiFailureOffline(
        'network unavailable',
      );
      await pumpScreen(tester);
      await openConfirmDialog(tester);

      await tester.tap(find.byKey(const Key('delete_account_confirm_accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeAccountApi.deleteAccountCalls, 1);
      expect(
        find.byKey(const Key('delete_account_confirm_dialog')),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('network unavailable'), findsOneWidget);
    });

    testWidgets(
      'successful server deletion offers a separate local-data wipe choice',
      (tester) async {
        // deleteAccount succeeds this time (default: no deleteAccountError),
        // so the screen should offer the local-namespace wipe as a distinct
        // second step before it moves on to sign-out/navigation.
        await pumpScreen(tester);
        await openConfirmDialog(tester);

        await tester.tap(
          find.byKey(const Key('delete_account_confirm_accept')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeAccountApi.deleteAccountCalls, 1);
        expect(
          find.byKey(const Key('delete_account_local_wipe_offer_dialog')),
          findsOneWidget,
          reason:
              'Server deletion succeeded, so the screen must now offer the '
              'separate local-device wipe step rather than silently leaving '
              "this account's local copy in place.",
        );

        // Choosing "keep local copy" must not touch local data (no wipe
        // confirmation dialog appears) and must dismiss this offer.
        await tester.tap(
          find.byKey(const Key('delete_account_local_wipe_skip')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('delete_account_local_wipe_offer_dialog')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('wipe_archive_confirm_field')),
          findsNothing,
          reason:
              'Declining the local wipe must not surface the destructive '
              'wipe-confirmation dialog.',
        );
      },
    );

    testWidgets(
      'accepting the local-data wipe offer opens the double-confirmation wipe dialog',
      (tester) async {
        await pumpScreen(tester);
        await openConfirmDialog(tester);

        await tester.tap(
          find.byKey(const Key('delete_account_confirm_accept')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(
          find.byKey(const Key('delete_account_local_wipe_accept')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The existing double-confirmation wipe dialog (shared with the
        // security settings "emergency wipe" flow) must gate the actual
        // local deletion — accepting the offer alone must not wipe anything.
        expect(
          find.byKey(const Key('wipe_archive_confirm_field')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('wipe_archive_cancel')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets('remains usable at 300% text scale (no overflow)', (
      tester,
    ) async {
      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        flutterErrors.add(details);
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: const DeleteAccountScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(flutterErrors, isEmpty);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('delete button stays reachable on a narrow small screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpScreen(tester);

      await tester.ensureVisible(
        find.byKey(const Key('delete_account_button')),
      );
      expect(find.byKey(const Key('delete_account_button')), findsOneWidget);
    });

    testWidgets('remains usable at 200% text scale (no overflow)', (
      tester,
    ) async {
      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        flutterErrors.add(details);
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const DeleteAccountScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(
        find.byKey(const Key('delete_account_button')),
      );
      await tester.tap(find.byKey(const Key('delete_account_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // A RenderFlex overflow (the classic 200%-scale failure mode) reports
      // through FlutterError.onError rather than throwing synchronously, so
      // assert on the captured error list rather than expecting a throw.
      expect(
        flutterErrors,
        isEmpty,
        reason:
            'Delete-account button/dialog overflowed at 200% text scale: '
            '${flutterErrors.map((d) => d.exceptionAsString()).join('; ')}',
      );
      expect(
        find.byKey(const Key('delete_account_confirm_dialog')),
        findsOneWidget,
      );
    });

    testWidgets('confirmation dialog exposes real semantics labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pumpScreen(tester);
      await openConfirmDialog(tester);

      expect(
        find.bySemanticsLabel('Delete account permanently?'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Delete permanently'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('delete_account_confirm_dialog')),
          matching: find.bySemanticsLabel('Cancel'),
        ),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('failed deletion stays explicit and allows retry', (
      tester,
    ) async {
      fakeAccountApi.deleteAccountFailure = const ApiFailureOffline(
        'network unavailable',
      );
      await pumpScreen(tester);
      await openConfirmDialog(tester);
      await tester.tap(find.byKey(const Key('delete_account_confirm_accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeAccountApi.deleteAccountCalls, 1);
      expect(find.text('network unavailable'), findsOneWidget);
      expect(
        find.textContaining('deletion requested'),
        findsNothing,
        reason: 'must not claim success when server deletion failed',
      );
      expect(
        find.text(DeleteAccountScreen.deletionCompletedMessage),
        findsNothing,
      );

      fakeAccountApi.deleteAccountFailure = null;
      await openConfirmDialog(tester);
      await tester.tap(find.byKey(const Key('delete_account_confirm_accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeAccountApi.deleteAccountCalls, 2);
      expect(
        find.byKey(const Key('delete_account_local_wipe_offer_dialog')),
        findsOneWidget,
      );
    });

    test('deletionCompletedMessage describes confirmed server deletion', () {
      expect(
        DeleteAccountScreen.deletionCompletedMessage.toLowerCase(),
        contains('deleted'),
      );
      expect(
        DeleteAccountScreen.deletionCompletedMessage.toLowerCase(),
        isNot(contains('requested')),
      );
      expect(
        DeleteAccountScreen.deletionCompletedMessage,
        contains('permanently removed'),
      );
    });

    testWidgets(
      'successful server deletion shows completion copy only after confirm',
      (tester) async {
        await pumpScreenWithRouter(tester);
        await openConfirmDialog(tester);
        await tester.tap(
          find.byKey(const Key('delete_account_confirm_accept')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Server data deleted'), findsOneWidget);
        expect(
          find.textContaining('deletion requested'),
          findsNothing,
          reason: 'must not claim a mere request before server confirms',
        );

        await tester.tap(
          find.byKey(const Key('delete_account_local_wipe_skip')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeAccountApi.deleteAccountCalls, 1);
      },
    );
  });
}