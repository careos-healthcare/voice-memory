import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/landing_continuity/landing_app_continuity_copy.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/auditable_change_positioning.dart';
import 'package:voicememory_mobile/product/core_product_vision.dart';
import 'package:voicememory_mobile/startup/archive_me_startup.dart';

void main() {
  const vision = AuditableChangePositioning.full;

  test('one product vision drives first-launch entry points', () {
    expect(CoreProductVision.valueProposition, vision);
    expect(LandingAppContinuityCopy.coreProductVision, vision);
    expect(OnboardingPages.pages.first.body, startsWith(vision));
    expect(VisibleArchiveProofCopy.firstRunRecordBody, vision);
    expect(CoreProductVision.appStoreSubtitle.length, lessThanOrEqualTo(30));
    expect(
      CoreProductVision.playStoreShortDescription.length,
      lessThanOrEqualTo(80),
    );
  });

  testWidgets('startup splash states the product vision', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ArchiveMeStartupSplash()));

    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(find.text(vision), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('App Store and Play metadata lead with the product vision', () {
    for (final path in [
      'docs/APP_STORE_COPY.md',
      'docs/PLAY_STORE_COPY.md',
      'ios/fastlane/metadata/en-US/promotional_text.txt',
      'ios/fastlane/metadata/en-US/description.txt',
    ]) {
      expect(File(path).readAsStringSync(), contains(vision), reason: path);
    }
    expect(
      File(
        'ios/fastlane/metadata/en-US/subtitle.txt',
      ).readAsStringSync().trim().length,
      lessThanOrEqualTo(30),
    );
  });
}
