import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/first_use_wording/first_use_wording_copy.dart';

/// Guided examples were replaced by FirstUseWordingHelper v1 — no duplicate surfaces.
void main() {
  test('legacy guided examples card is not shipped', () {
    expect(
      const Key('guided_examples_card').toString(),
      isNot(contains(FirstUseWordingCopy.title)),
    );
  });

  test('first-use wording helper copy replaces guided examples', () {
    expect(FirstUseWordingCopy.title, 'Try starting with one real sentence');
    expect(FirstUseWordingCopy.useOpeningCta, 'Use this opening');
  });
}
