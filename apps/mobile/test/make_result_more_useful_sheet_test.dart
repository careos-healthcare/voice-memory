import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/widgets/record/make_result_more_useful_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('options map labels to the takeaway not-useful reasons', () {
    final byLabel = {
      for (final o in MakeResultMoreUsefulSheet.options) o.label: o.reason,
    };
    expect(
      byLabel[ConsumerUiCopy.makeResultMoreUsefulMoreSpecific],
      'too_vague',
    );
    expect(
      byLabel[ConsumerUiCopy.makeResultMoreUsefulMoreAccurate],
      'not_accurate',
    );
    expect(
      byLabel[ConsumerUiCopy.makeResultMoreUsefulMoreNextStep],
      'already_knew_this',
    );
    expect(byLabel[ConsumerUiCopy.makeResultMoreUsefulEasier], 'confusing');
  });

  testWidgets('sheet opens and returns the selected reason', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await MakeResultMoreUsefulSheet.show(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text(ConsumerUiCopy.makeResultMoreUsefulSheetTitle),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.makeResultMoreUsefulMoreSpecific),
      findsOneWidget,
    );

    await tester.tap(
      find.text(ConsumerUiCopy.makeResultMoreUsefulMoreSpecific),
    );
    await tester.pumpAndSettle();

    expect(result, 'too_vague');
  });
}