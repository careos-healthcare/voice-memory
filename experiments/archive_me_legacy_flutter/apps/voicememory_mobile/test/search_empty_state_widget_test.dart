import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/empty_states/search_empty_state.dart';

void main() {
  group('SearchEmptyState widget', () {
    setUp(() async {
      // SearchEmptyState embeds StartHereLoader, which reads AppServices in
      // initState — initialize it so the widget can build under test.
      final tempDir = Directory.systemTemp.createTempSync('vm_search_empty_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
    });

    testWidgets('renders title, bullets, examples, and CTAs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SearchEmptyState()),
        ),
      );

      expect(find.text('Nothing to search yet'), findsOneWidget);
      expect(find.text("You'll be able to search for:"), findsOneWidget);
      expect(find.text("beliefs you've repeated"), findsOneWidget);
      expect(find.text('people, places, and events'), findsOneWidget);
      expect(
        find.text('Months from now you might search for:'),
        findsOneWidget,
      );
      expect(find.text('"confidence"'), findsOneWidget);
      expect(find.text('"burnout"'), findsOneWidget);
      expect(find.text('"starting a business"'), findsOneWidget);
      expect(find.text('"I\'m not ready"'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.startRecording), findsOneWidget);
      expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
      expect(find.byType(SearchEmptyState), findsOneWidget);
      expect(find.byType(IntentionalEmptyArchiveView), findsNothing);
    });
  });
}
