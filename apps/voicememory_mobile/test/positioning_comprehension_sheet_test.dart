import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/trial/positioning_comprehension_model.dart';
import 'package:voicememory_mobile/features/trial/positioning_comprehension_store.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/trial/positioning_comprehension_sheet.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_positioning_sheet_journal_$stamp.json',
    prefsPath: '/tmp/vm_positioning_sheet_prefs_$stamp.json',
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

void main() {
  testWidgets('comprehension sheet records archive memory choice', (
    tester,
  ) async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = PositioningComprehensionStore(AppServices.instance.prefs);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => PositioningComprehensionSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await _openSheet(tester);

    expect(find.text(PositioningComprehensionCopy.question), findsOneWidget);
    await tester.tap(
      find.text(PositioningComprehensionCopy.archiveMemoryLabel),
    );
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    PositioningComprehensionAnswer? savedAnswer;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(await store.hasAnswered(), isTrue);
      final all = await store.loadAll();
      savedAnswer = all.first.answer;
    });
    expect(savedAnswer, PositioningComprehensionAnswer.archiveMemory);
  });
}
