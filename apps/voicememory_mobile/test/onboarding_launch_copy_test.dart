import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/auditable_change_positioning.dart';

void main() {
  test('launch onboarding is a single promise before capture', () {
    expect(OnboardingPages.pageCount, 1);
    expect(OnboardingPages.pages, hasLength(1));
    expect(OnboardingPages.primaryAction, 'Record a moment');
    expect(OnboardingPages.secondaryAction, 'Type instead');
  });

  test('page 1 — landing welcome promise', () {
    final page = OnboardingPages.pages[0];
    expect(page.title, AuditableChangePositioning.primaryPromise);
    expect(page.body, startsWith(AuditableChangePositioning.full));
    expect(page.body, contains('the words proving it'));
    expect(page.title.toLowerCase(), isNot(contains('pressure loops')));
  });

  test('launch copy does not ask for people, focus, or goals', () {
    final copy = OnboardingPages.pages
        .expand((page) => [page.title, page.body])
        .join(' ')
        .toLowerCase();
    expect(copy, isNot(contains('two people')));
    expect(copy, isNot(contains('main focus')));
    expect(copy, isNot(contains('goal or challenge')));
  });
}
