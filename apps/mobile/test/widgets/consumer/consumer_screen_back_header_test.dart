import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/consumer/consumer_screen_back_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps a 48pt minimum tap target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ConsumerScreenBackHeader()),
      ),
    );
    await tester.pump();

    final size = tester.getSize(
      find.byKey(const Key('consumer_screen_back_header')),
    );
    expect(
      size.height,
      greaterThanOrEqualTo(ConsumerScreenBackHeader.minTapTarget),
    );
    expect(
      size.width,
      greaterThanOrEqualTo(ConsumerScreenBackHeader.minTapTarget),
    );
  });
}
