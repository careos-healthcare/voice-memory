import 'package:archiveme_mobile/features/import/views/import_receipt_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('receipt shows the original recording date and saves on request', (
    tester,
  ) async {
    var saved = false;
    final recorded = DateTime.utc(2023, 11, 4, 15);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ImportReceiptView(
                    transcript: 'el rio estaba alto',
                    recordedAt: recorded,
                    onSave: () async => saved = true,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import_receipt_headline')), findsOneWidget);
    expect(find.text('Voice Memo Imported'), findsWidgets);
    expect(find.text('el rio estaba alto'), findsOneWidget);
    final date = tester
        .widget<Text>(find.byKey(const Key('import_receipt_entry_date')))
        .data!;
    expect(
      date,
      'Imported from Voice Memos · recorded 4 Nov 2023',
    );

    await tester.tap(find.byKey(const Key('import_receipt_save')));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(find.byKey(const Key('import_receipt_headline')), findsNothing);
  });
}
