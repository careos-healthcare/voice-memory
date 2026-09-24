import 'package:archiveme_mobile/features/onboarding/privacy_onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rationale comes before the system prompt', (tester) async {
    var requests = 0;
    var purchases = 0;
    var finished = false;
    final permissions = OnboardingPermissionClient(
      status: (_) async => PermissionStatus.denied,
      request: (_) async {
        requests += 1;
        return PermissionStatus.granted;
      },
      openSettings: () async => true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyOnboardingFlow(
          permissions: permissions,
          preparePurchases: () async {
            purchases += 1;
          },
          onFinished: () => finished = true,
        ),
      ),
    );

    expect(find.text('Your words stay on this device'), findsOneWidget);
    expect(requests, 0);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('system prompt appears after you continue'),
      findsOneWidget,
    );
    expect(requests, 0);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(purchases, 1);
    expect(find.text('Save your first moment'), findsOneWidget);

    await tester.tap(find.text('Start recording'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('a permanent denial opens Settings', (tester) async {
    var opened = false;
    final permissions = OnboardingPermissionClient(
      status: (_) async => PermissionStatus.permanentlyDenied,
      request: (_) async => PermissionStatus.granted,
      openSettings: () async {
        opened = true;
        return true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyOnboardingFlow(
          permissions: permissions,
          preparePurchases: () async {},
          onFinished: () {},
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Open Settings'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    expect(opened, isTrue);
  });
}
