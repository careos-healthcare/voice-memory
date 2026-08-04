import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ios_device_viewport.dart';

Rect visibleRect(WidgetTester tester, Finder finder) {
  final window =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  return tester.getRect(finder).intersect(window);
}

void expectNoLayoutException(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'Render/layout exception at the current iOS matrix state',
  );
}

void expectVisibleTapTarget(
  WidgetTester tester,
  Finder finder, {
  double minimum = 44,
}) {
  final rect = visibleRect(tester, finder);
  expect(rect.width, greaterThanOrEqualTo(minimum), reason: '$finder width');
  expect(rect.height, greaterThanOrEqualTo(minimum), reason: '$finder height');
}

void expectTapSemantics(WidgetTester tester, Finder finder) {
  final handle = tester.ensureSemantics();
  try {
    expect(
      tester
          .getSemantics(finder)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
      reason: '$finder must expose a semantic tap action',
    );
  } finally {
    handle.dispose();
  }
}

void expectInsideSafeHorizontalBounds(
  WidgetTester tester,
  Finder finder,
  IosDeviceViewport viewport,
) {
  final rect = visibleRect(tester, finder);
  expect(rect.left, greaterThanOrEqualTo(viewport.padding.left));
  expect(
    rect.right,
    lessThanOrEqualTo(viewport.logicalSize.width - viewport.padding.right),
  );
}

void expectSafeBodyBounds(
  WidgetTester tester,
  Finder finder,
  IosDeviceViewport viewport,
) {
  final rect = visibleRect(tester, finder);
  expect(rect.left, greaterThanOrEqualTo(viewport.padding.left));
  expect(
    rect.right,
    lessThanOrEqualTo(viewport.logicalSize.width - viewport.padding.right),
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(viewport.logicalSize.height - viewport.padding.bottom),
  );
}

void expectSheetInsideSafeArea(
  WidgetTester tester,
  Finder finder,
  IosDeviceViewport viewport,
) {
  final keyedSafeArea = find.byWidgetPredicate(
    (widget) =>
        widget is SafeArea && widget.key == tester.widget<Widget>(finder).key,
  );
  final ancestorSafeArea = find.ancestor(
    of: finder,
    matching: find.byType(SafeArea),
  );
  final descendantSafeArea = find.descendant(
    of: finder,
    matching: find.byType(SafeArea),
  );
  final safeAreaElements = <Element>{
    ...keyedSafeArea.evaluate(),
    ...ancestorSafeArea.evaluate(),
    ...descendantSafeArea.evaluate(),
  };
  if (safeAreaElements.isNotEmpty) {
    var left = 0.0;
    var right = 0.0;
    var bottom = 0.0;
    for (final element in safeAreaElements) {
      final safeArea = find.byElementPredicate(
        (candidate) => identical(candidate, element),
      );
      final padding = find.descendant(
        of: safeArea,
        matching: find.byType(Padding),
      );
      if (padding.evaluate().isEmpty) continue;
      final renderPadding = tester.renderObject<RenderPadding>(padding.first);
      final resolved = renderPadding.padding.resolve(TextDirection.ltr);
      left = left < resolved.left ? resolved.left : left;
      right = right < resolved.right ? resolved.right : right;
      bottom = bottom < resolved.bottom ? resolved.bottom : bottom;
    }
    expect(left, greaterThanOrEqualTo(viewport.padding.left));
    expect(right, greaterThanOrEqualTo(viewport.padding.right));
    expect(bottom, greaterThanOrEqualTo(viewport.padding.bottom));
    return;
  }
  expectSafeBodyBounds(tester, finder, viewport);
}
