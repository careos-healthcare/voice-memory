import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_consent_form.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_disclosure_screen.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_entry_point.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_flow.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_issuer.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingIssuer implements CaregiverGrantIssuer {
  final List<CaregiverGrantRequest> requests = [];

  @override
  Future<CaregiverGrantOutcome> issue(CaregiverGrantRequest request) async {
    requests.add(request);
    return CaregiverGrantGranted(
      tokenId: 'token-1',
      expiresAt: DateTime.utc(2026, 9, 21),
    );
  }
}

Future<void> _pumpFlowHost(
  WidgetTester tester, {
  required CaregiverGrantIssuer issuer,
  required void Function(bool) onResult,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: ListView(
            children: [
              CaregiverEntryPoint(
                onSetUpAccess: () async {
                  onResult(
                    await CaregiverGrantFlow.start(context, issuer: issuer),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(CaregiverConsentForm.nameFieldKey),
    'Sam Rivera',
  );
  await tester.enterText(
    find.byKey(CaregiverConsentForm.emailFieldKey),
    'sam@example.com',
  );
}

void main() {
  setUp(() => CaregiverFeatureFlags.debugOverride = true);
  tearDown(() => CaregiverFeatureFlags.debugOverride = null);

  group('caregiver grant flow', () {
    testWidgets('entry point to disclosure to form, then grants', (
      tester,
    ) async {
      final issuer = _RecordingIssuer();
      bool? result;
      await _pumpFlowHost(
        tester,
        issuer: issuer,
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(CaregiverEntryPoint.actionKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CaregiverDisclosureScreen.screenKey), findsOneWidget);
      expect(find.byKey(CaregiverConsentForm.screenKey), findsNothing);

      await tester.tap(find.byKey(CaregiverDisclosureScreen.continueKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CaregiverConsentForm.screenKey), findsOneWidget);

      await _fillValidForm(tester);
      await tester.tap(find.byKey(CaregiverConsentForm.grantKey));
      await tester.pumpAndSettle();

      expect(issuer.requests, hasLength(1));
      expect(result, isTrue);
    });

    testWidgets('cancelling the disclosure exits without granting', (
      tester,
    ) async {
      final issuer = _RecordingIssuer();
      bool? result;
      await _pumpFlowHost(
        tester,
        issuer: issuer,
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(CaregiverEntryPoint.actionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CaregiverDisclosureScreen.cancelKey));
      await tester.pumpAndSettle();

      expect(find.byKey(CaregiverDisclosureScreen.screenKey), findsNothing);
      expect(find.byKey(CaregiverConsentForm.screenKey), findsNothing);
      expect(find.byKey(CaregiverEntryPoint.cardKey), findsOneWidget);
      expect(issuer.requests, isEmpty);
      expect(result, isFalse);
    });

    testWidgets('cancelling the form exits without granting', (tester) async {
      final issuer = _RecordingIssuer();
      bool? result;
      await _pumpFlowHost(
        tester,
        issuer: issuer,
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(CaregiverEntryPoint.actionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CaregiverDisclosureScreen.continueKey));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.byKey(CaregiverConsentForm.cancelKey));
      await tester.pumpAndSettle();

      expect(find.byKey(CaregiverConsentForm.screenKey), findsNothing);
      expect(find.byKey(CaregiverEntryPoint.cardKey), findsOneWidget);
      expect(issuer.requests, isEmpty);
      expect(result, isFalse);
    });

    testWidgets('the flag gates the flow, not just the card', (tester) async {
      CaregiverFeatureFlags.debugOverride = false;
      final issuer = _RecordingIssuer();
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await CaregiverGrantFlow.start(
                    context,
                    issuer: issuer,
                  );
                },
                child: const Text('start'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.byKey(CaregiverDisclosureScreen.screenKey), findsNothing);
      expect(issuer.requests, isEmpty);
      expect(result, isFalse);
    });
  });
}
