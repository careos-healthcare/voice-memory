import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_consent_form.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_issuer.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingIssuer implements CaregiverGrantIssuer {
  _RecordingIssuer({this.outcome});

  final CaregiverGrantOutcome? outcome;
  final List<CaregiverGrantRequest> requests = [];

  @override
  Future<CaregiverGrantOutcome> issue(CaregiverGrantRequest request) async {
    requests.add(request);
    return outcome ??
        CaregiverGrantGranted(
          tokenId: 'token-1',
          expiresAt: DateTime.utc(2026, 9, 21),
        );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  CaregiverGrantIssuer? issuer,
  VoidCallback? onCancel,
  void Function(CaregiverGrantGranted)? onGranted,
  double textScale = 1,
  Size viewSize = const Size(400, 4000),
}) {
  // The four new sharing toggles push later content well below the
  // default 800x600 test window, where a lazy ListView never builds its
  // offscreen children and a finder reports them as missing rather than
  // unbuilt -- same pattern as caregiver_grant_settings_entry_test.dart.
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: CaregiverConsentForm(
          issuer: issuer ?? const UnwiredCaregiverGrantIssuer(),
          onCancel: onCancel,
          onGranted: onGranted,
        ),
      ),
    ),
  );
}

void main() {
  group('CaregiverConsentForm', () {
    testWidgets('renders both fields and both actions', (tester) async {
      await _pump(tester);

      expect(find.byKey(CaregiverConsentForm.nameFieldKey), findsOneWidget);
      expect(find.byKey(CaregiverConsentForm.emailFieldKey), findsOneWidget);
      expect(find.byKey(CaregiverConsentForm.cancelKey), findsOneWidget);
      expect(find.byKey(CaregiverConsentForm.grantKey), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.thirdPartyNote), findsOneWidget);
    });

    testWidgets('Cancel is visible and keeps a 48dp target', (tester) async {
      await _pump(tester);

      final cancel = find.byKey(CaregiverConsentForm.cancelKey);
      final rect = tester.getRect(cancel);
      final screen = tester.getSize(find.byType(MaterialApp));
      expect(rect.bottom, lessThanOrEqualTo(screen.height));
      expect(rect.height, greaterThanOrEqualTo(48));
    });

    testWidgets('Cancel exits without issuing a grant', (tester) async {
      final issuer = _RecordingIssuer();
      var cancelled = 0;
      await _pump(tester, issuer: issuer, onCancel: () => cancelled += 1);

      await tester.enterText(
        find.byKey(CaregiverConsentForm.nameFieldKey),
        'Sam Rivera',
      );
      await tester.tap(find.byKey(CaregiverConsentForm.cancelKey));
      await tester.pump();

      expect(cancelled, 1);
      expect(issuer.requests, isEmpty);
    });

    testWidgets('an empty name blocks submission and shows an error', (
      tester,
    ) async {
      final issuer = _RecordingIssuer();
      await _pump(tester, issuer: issuer);

      await tester.enterText(
        find.byKey(CaregiverConsentForm.emailFieldKey),
        'sam@example.com',
      );
      await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
      await tester.pumpAndSettle();

      expect(find.text(CaregiverGrantCopy.nameError), findsOneWidget);
      expect(issuer.requests, isEmpty);
    });

    testWidgets('a malformed email blocks submission and shows an error', (
      tester,
    ) async {
      final issuer = _RecordingIssuer();
      await _pump(tester, issuer: issuer);

      await tester.enterText(
        find.byKey(CaregiverConsentForm.nameFieldKey),
        'Sam Rivera',
      );
      for (final malformed in ['sam', 'sam@', '@example.com', 'sam@example']) {
        await tester.enterText(
          find.byKey(CaregiverConsentForm.emailFieldKey),
          malformed,
        );
        await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
        await tester.pumpAndSettle();

        expect(
          find.text(CaregiverGrantCopy.emailError),
          findsOneWidget,
          reason: malformed,
        );
        expect(issuer.requests, isEmpty, reason: malformed);
      }
    });

    testWidgets('the validation error is reachable by a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
      await tester.pumpAndSettle();

      final node = tester.getSemantics(
        find.byKey(CaregiverConsentForm.emailFieldKey),
      );
      expect(node.value, isNot(contains(CaregiverGrantCopy.emailError)));
      expect(
        find.bySemanticsLabel(RegExp(CaregiverGrantCopy.emailError)),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('a valid form issues a grant with an opaque caregiver id', (
      tester,
    ) async {
      final issuer = _RecordingIssuer();
      CaregiverGrantGranted? granted;
      await _pump(
        tester,
        issuer: issuer,
        onGranted: (outcome) => granted = outcome,
      );

      await tester.enterText(
        find.byKey(CaregiverConsentForm.nameFieldKey),
        'Sam Rivera',
      );
      await tester.enterText(
        find.byKey(CaregiverConsentForm.emailFieldKey),
        'sam@example.com',
      );
      await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
      await tester.pumpAndSettle();

      expect(issuer.requests, hasLength(1));
      final request = issuer.requests.single;
      expect(request.contact.name, 'Sam Rivera');
      expect(request.contact.email, 'sam@example.com');
      expect(request.caregiverId, isNotEmpty);
      expect(
        request.caregiverId,
        isNot(contains('@')),
        reason: 'the third-party email must not travel as the caregiver id',
      );
      expect(request.caregiverId, isNot(contains('Sam')));
      expect(granted?.tokenId, 'token-1');
    });

    testWidgets('all four sharing toggles default to off', (tester) async {
      final issuer = _RecordingIssuer();
      await _pump(tester, issuer: issuer);

      await tester.enterText(
        find.byKey(CaregiverConsentForm.nameFieldKey),
        'Sam Rivera',
      );
      await tester.enterText(
        find.byKey(CaregiverConsentForm.emailFieldKey),
        'sam@example.com',
      );
      await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
      await tester.pumpAndSettle();

      final request = issuer.requests.single;
      expect(request.shareJournal, isFalse);
      expect(request.shareProofTrail, isFalse);
      expect(request.shareTimeline, isFalse);
      expect(request.shareReviewSummaries, isFalse);
    });

    testWidgets('toggling a switch flows through to the request', (
      tester,
    ) async {
      final issuer = _RecordingIssuer();
      await _pump(tester, issuer: issuer);

      await tester.enterText(
        find.byKey(CaregiverConsentForm.nameFieldKey),
        'Sam Rivera',
      );
      await tester.enterText(
        find.byKey(CaregiverConsentForm.emailFieldKey),
        'sam@example.com',
      );
      await tester.tap(find.byKey(CaregiverConsentForm.journalToggleKey));
      await tester.tap(find.byKey(CaregiverConsentForm.timelineToggleKey));
      await tester.tap(
        find.byKey(CaregiverConsentForm.reviewSummariesToggleKey),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
      await tester.pumpAndSettle();

      final request = issuer.requests.single;
      expect(request.shareJournal, isTrue);
      expect(request.shareProofTrail, isFalse);
      expect(request.shareTimeline, isTrue);
      expect(request.shareReviewSummaries, isTrue);
    });

    testWidgets('a refused grant shows a recoverable error', (tester) async {
      final issuer = _RecordingIssuer(
        outcome: const CaregiverGrantFailed('backend not configured'),
      );
      await _pump(tester, issuer: issuer);

      await tester.enterText(
        find.byKey(CaregiverConsentForm.nameFieldKey),
        'Sam Rivera',
      );
      await tester.enterText(
        find.byKey(CaregiverConsentForm.emailFieldKey),
        'sam@example.com',
      );
      await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
      await tester.pumpAndSettle();

      expect(find.byKey(CaregiverConsentForm.errorKey), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.grantUnavailable), findsOneWidget);
    });

    testWidgets('the default issuer refuses to grant', (tester) async {
      await _pump(tester);

      await tester.enterText(
        find.byKey(CaregiverConsentForm.nameFieldKey),
        'Sam Rivera',
      );
      await tester.enterText(
        find.byKey(CaregiverConsentForm.emailFieldKey),
        'sam@example.com',
      );
      await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
      await tester.pumpAndSettle();

      expect(find.byKey(CaregiverConsentForm.errorKey), findsOneWidget);
    });

    testWidgets('stays usable at 3x text scale', (tester) async {
      final issuer = _RecordingIssuer();
      await _pump(
        tester,
        issuer: issuer,
        textScale: 3,
        viewSize: const Size(360 * 3, 4000),
      );
      tester.view.devicePixelRatio = 3;

      expect(tester.takeException(), isNull);

      final cancel = find.byKey(CaregiverConsentForm.cancelKey);
      final grant = find.byKey(CaregiverConsentForm.grantKey);
      expect(cancel, findsOneWidget);
      expect(grant, findsOneWidget);
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(grant).height, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(cancel).bottom,
        lessThanOrEqualTo(tester.getSize(find.byType(MaterialApp)).height),
      );
    });
  });
}
