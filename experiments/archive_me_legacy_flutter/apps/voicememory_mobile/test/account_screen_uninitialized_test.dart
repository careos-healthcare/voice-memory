import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';

import 'support/provider_test_harness.dart';

void main() {
  testWidgets('renders model UI before AppServices initialization', (
    tester,
  ) async {
    expect(AppServices.isInitialized, isFalse);
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      providerTestHarness(
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountScreen(
            weeklyGrowthPreviewCard: SizedBox(
              key: Key('weekly_growth_preview_card'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.byKey(const Key('llama_model_download_card')), findsOneWidget);
    expect(
      find.byKey(const Key('llama_model_download_source_account')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
