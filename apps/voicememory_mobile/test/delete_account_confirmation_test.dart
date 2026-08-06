import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/screens/delete_account_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';

/// Records calls; no HTTP, no real backend — mirrors the fake-API pattern
/// used across the auth tests (see `account_auth_test.dart`).
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.invalid');

  int deleteAccountCalls = 0;
  Object? deleteAccountError;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
    final error = deleteAccountError;
    if (error != null) throw error;
  }
}

/// Delete account is destructive and irreversible, so it must always require
/// an explicit confirmation step before the network call fires — see the
/// accessibility audit's "destructive confirmation dialogs" requirement.
///
/// NOTE: deliberately avoids `pumpAndSettle` (which never quiesces in this
/// app's widget-test harness) in favor of the fixed-duration `pump()` pattern
/// already used elsewhere, e.g. `account_auth_test.dart`.
void main() {
  late Directory tempDir;
  late _FakeApi fakeApi;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('delete_account_test_');
    fakeApi = _FakeApi();
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
      api: fakeApi,
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeleteAccountScreen()));
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
      expect(fakeApi.deleteAccountCalls, 0);
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
      expect(fakeApi.deleteAccountCalls, 0);
    });

    testWidgets('confirming dismisses the dialog and calls deleteAccount', (
      tester,
    ) async {
      // Fail the call deliberately: on success the screen calls
      // `context.go('/record')`, which needs a GoRouter this test's plain
      // `MaterialApp` doesn't provide. This test only asserts the
      // confirmation gate calls through to the API — not the post-success
      // navigation, which is exercised by the app's real router elsewhere.
      fakeApi.deleteAccountError = Exception('network unavailable');
      await pumpScreen(tester);
      await openConfirmDialog(tester);

      await tester.tap(find.byKey(const Key('delete_account_confirm_accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeApi.deleteAccountCalls, 1);
      expect(
        find.byKey(const Key('delete_account_confirm_dialog')),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Account deletion failed. Try again.'), findsOneWidget);
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

        expect(fakeApi.deleteAccountCalls, 1);
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
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const DeleteAccountScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.byKey(const Key('delete_account_button')));
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
  });
}
