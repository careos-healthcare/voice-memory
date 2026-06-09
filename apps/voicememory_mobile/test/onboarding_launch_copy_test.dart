import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('launch onboarding has four prove-focused pages', () {
    expect(OnboardingPages.pageCount, 4);
    expect(OnboardingPages.pages, hasLength(4));
  });

  test('page 1 — doing more does not always feel like enough', () {
    final page = OnboardingPages.pages[0];
    expect(page.title, ConsumerUiCopy.onboardingPositioningHeadline);
    expect(page.body, ConsumerUiCopy.onboardingPositioningBody);
  });

  test('page 2 — record the moment', () {
    final page = OnboardingPages.pages[1];
    expect(page.title, ConsumerUiCopy.onboardingPage2Title);
    expect(page.body, ConsumerUiCopy.onboardingPage2Body);
  });

  test('page 3 — test across a few moments', () {
    final page = OnboardingPages.pages[2];
    expect(page.title, ConsumerUiCopy.onboardingPage3Title);
    expect(page.body, ConsumerUiCopy.onboardingPage3Body);
  });

  test('page 4 — review what keeps repeating', () {
    final page = OnboardingPages.pages[3];
    expect(page.title, ConsumerUiCopy.onboardingPage4Title);
    expect(page.body, ConsumerUiCopy.onboardingPage4Body);
  });

  test('final CTA is Start with one moment', () {
    expect(ConsumerUiCopy.onboardingFinalCta, 'Start with one moment');
    expect(ConsumerUiCopy.onboardingBeginCta, ConsumerUiCopy.onboardingFinalCta);
  });
}
