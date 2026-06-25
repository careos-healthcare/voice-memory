import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/subscription_review_preview.dart';

/// Host golden export for App Store review (393×852 logical, @3x golden).
void main() {
  testWidgets('subscription review preview golden', (tester) async {
    if (Platform.environment['ARCHIVEME_RUN_PNG_EXPORT'] != 'true') return;

    const logicalSize = Size(393, 852);
    await tester.binding.setSurfaceSize(logicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: logicalSize),
          child: SizedBox(
            width: logicalSize.width,
            height: logicalSize.height,
            child: const SubscriptionReviewPreviewScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(SubscriptionReviewPreviewScreen),
      matchesGoldenFile('subscription_review_preview.png'),
    );
  });
}
