import 'package:archiveme_mobile/features/export/views/pod_checkout_view.dart';
import 'package:archiveme_mobile/features/export/views/printed_book_order_view.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pay stays closed until the Lulu upload is accepted', (
    tester,
  ) async {
    var paid = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PrintedBookOrderView(
          pageCount: 12,
          onPay: (_) async => paid = true,
        ),
      ),
    );
    expect(find.text(podPrintConsentCopy), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('printed_book_pay'))).onPressed,
      isNull,
    );
    expect(paid, isFalse);

    await tester.tap(find.byKey(const Key('printed_book_consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('printed_book_pay')));
    await tester.pump();
    expect(paid, isTrue);
  });
}