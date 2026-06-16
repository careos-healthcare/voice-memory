import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('launch onboarding has promise plus three loop steps', () {
    expect(OnboardingPages.pageCount, 4);
    expect(OnboardingPages.pages, hasLength(4));
  });

  test('page 1 — pressure loop promise', () {
    final page = OnboardingPages.pages[0];
    expect(page.title, ConsumerUiCopy.onboardingPositioningHeadline);
    expect(page.body, ConsumerUiCopy.onboardingPositioningBody);
  });

  test('page 2 — record one small moment', () {
    final page = OnboardingPages.pages[1];
    expect(page.title, ConsumerUiCopy.onboardingStep1Title);
    expect(page.body, ConsumerUiCopy.onboardingStep1Body);
    expect(page.stepNumber, 1);
  });

  test('page 3 — notices what repeats', () {
    final page = OnboardingPages.pages[2];
    expect(page.title, ConsumerUiCopy.onboardingStep2Title);
    expect(page.body, ConsumerUiCopy.onboardingStep2Body);
    expect(page.stepNumber, 2);
  });

  test('page 4 — return tomorrow', () {
    final page = OnboardingPages.pages[3];
    expect(page.title, ConsumerUiCopy.onboardingStep3Title);
    expect(page.body, ConsumerUiCopy.onboardingStep3Body);
    expect(page.stepNumber, 3);
  });

  test('final CTA is Start my archive', () {
    expect(ConsumerUiCopy.onboardingFinalCta, 'Start my archive');
    expect(
      ConsumerUiCopy.onboardingBeginCta,
      ConsumerUiCopy.onboardingFinalCta,
    );
  });
}
