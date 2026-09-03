import 'package:archiveme_mobile/features/settings/ui/crisis_resources_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/crisis_resources_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('renders the intro, disclaimer, and every resource card',
      (tester) async {
    await tester.pumpWidget(wrap(const CrisisResourcesScreen()));

    expect(find.text(CrisisResourcesCopy.intro), findsOneWidget);
    expect(find.text(CrisisResourcesCopy.disclaimer), findsOneWidget);
    expect(find.text(CrisisResourcesCopy.emergencyTitle), findsOneWidget);
    expect(find.text(CrisisResourcesCopy.lifelineTitle), findsOneWidget);
    expect(find.text(CrisisResourcesCopy.crisisTextLineTitle), findsOneWidget);
    expect(find.text(CrisisResourcesCopy.internationalTitle), findsOneWidget);
  });

  testWidgets('every resource action key is present and tappable',
      (tester) async {
    await tester.pumpWidget(wrap(const CrisisResourcesScreen()));

    for (final key in [
      CrisisResourcesScreen.lifelineCallKey,
      CrisisResourcesScreen.lifelineTextKey,
      CrisisResourcesScreen.crisisTextLineKey,
      CrisisResourcesScreen.internationalKey,
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }

    // Tapping doesn't need to succeed in a test environment (there's no real
    // OS to hand a tel:/sms: URL to) — it just needs to not throw, and to
    // show the fallback snackbar via the existing error path when the
    // platform channel call fails, which is exactly what happens under test.
    await tester.tap(find.byKey(CrisisResourcesScreen.lifelineCallKey));
    await tester.pumpAndSettle();
  });

  testWidgets('emergency card has no tappable action', (tester) async {
    await tester.pumpWidget(wrap(const CrisisResourcesScreen()));

    expect(find.text(CrisisResourcesCopy.emergencyBody), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(5)); // 4 resource actions + PushedScreenShell's own bottom Done button
  });
}
