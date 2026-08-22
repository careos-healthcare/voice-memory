import 'dart:io';

import 'package:archiveme_research/screens/subscription_review_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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