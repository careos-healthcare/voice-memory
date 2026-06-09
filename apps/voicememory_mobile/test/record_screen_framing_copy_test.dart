import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  group('RecordScreenFramingCopy', () {
    test('uses concrete first-recording guidance', () {
      expect(RecordScreenFramingCopy.title, 'What is on your mind?');
      expect(
        RecordScreenFramingCopy.guidance,
        'Speak naturally. Small moments become patterns.',
      );
    });

    test('does not include legacy abstract subheads', () {
      expect(RecordScreenFramingCopy.guidance, isNot(contains('Small things')));
      expect(RecordScreenFramingCopy.guidance, isNot(contains('ordinary moments')));
      expect(RecordScreenFramingCopy.helperLine, isNot(contains('ordinary moments')));
    });
  });

  group('RecordScreen framing UI', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_record_framing_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    testWidgets('record screen avoids legacy empty framing copy', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RecordScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(RecordScreenFramingCopy.title, isNotEmpty);
      expect(RecordScreenFramingCopy.guidance, isNotEmpty);
      expect(find.text('Small things become patterns.'), findsNothing);
      expect(
        find.text('The archive is built from ordinary moments.'),
        findsNothing,
      );
    });
  });
}
