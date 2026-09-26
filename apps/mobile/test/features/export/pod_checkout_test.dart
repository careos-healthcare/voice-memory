import 'dart:typed_data';

import 'package:archiveme_mobile/features/export/services/pod_api_service.dart';
import 'package:archiveme_mobile/features/export/views/pod_checkout_view.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a print upload is refused until consent, and an order waits for that upload',
    () async {
      final service = PodApiService();
      final pdf = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        service.uploadPdfToPrinter(pdf),
        throwsA(isA<PodConsentRequired>()),
      );
      await expectLater(
        service.createPrintOrder(const BookOptions(cover: BookCover.hardcover)),
        throwsA(isA<PodConsentRequired>()),
      );

      service.grantUploadConsent();
      await expectLater(
        service.createPrintOrder(const BookOptions(cover: BookCover.softcover)),
        throwsA(isA<PodUploadRequired>()),
      );
      await service.uploadPdfToPrinter(pdf);
      await service.createPrintOrder(
        const BookOptions(
          cover: BookCover.hardcover,
          margins: BookMargins(insideMm: 24),
        ),
      );
      expect(service.uploadedPdf, pdf);
      expect(service.lastOrder?.cover, BookCover.hardcover);
      expect(service.lastOrder?.margins.insideMm, 24);
    },
  );

  testWidgets('checkout stays closed until the upload checkbox is tapped', (
    tester,
  ) async {
    final service = PodApiService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PodCheckoutView(
          pdf: Uint8List.fromList([9, 8, 7]),
          service: service,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(podPrintConsentCopy), findsOneWidget);
    expect(find.byKey(const Key('pod_cover_hardcover')), findsNothing);
    expect(service.consentGranted, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('pod_upload_continue')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('pod_consent_checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('pod_upload_continue')))
          .onPressed,
      isNotNull,
    );
    expect(service.uploadedPdf, isNull);

    await tester.tap(find.byKey(const Key('pod_upload_continue')));
    await tester.pumpAndSettle();
    expect(service.consentGranted, isTrue);
    expect(service.uploadedPdf, Uint8List.fromList([9, 8, 7]));
    expect(find.byKey(const Key('pod_cover_hardcover')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pod_cover_hardcover')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pod_place_order')));
    await tester.pumpAndSettle();
    expect(service.lastOrder?.cover, BookCover.hardcover);
    expect(find.byKey(const Key('pod_order_saved')), findsOneWidget);
  });
}
