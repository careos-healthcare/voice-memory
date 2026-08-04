import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/services/app_services.dart';

import '../tool/full_visual_audit.dart';

/// Simulator/device layout evidence.
///
/// Unlike host viewport widget tests, this reads the real runner window's
/// MediaQuery and screenshots the rendered iOS surface. Set the simulator or
/// physical iPhone Dynamic Type before launch; the test does not fake it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const requireAccessibilityText = bool.fromEnvironment(
    'IOS_LAYOUT_REQUIRE_ACCESSIBILITY_TEXT',
  );

  testWidgets('iOS routes respect the runner safe area without overflow', (
    tester,
  ) async {
    await VisualAuditFixtures.prepareApp();
    await AppServices.instance.prefs.setOnboardingCompleted(true);
    onboardingGate.markComplete();
    await tester.pumpWidget(const ArchiveMeApp());
    await _pumpFrames(tester, 30);

    final initialMediaQuery = _mediaQuery(tester);
    expect(initialMediaQuery.size.width, greaterThan(0));
    expect(initialMediaQuery.size.height, greaterThan(0));
    expect(initialMediaQuery.viewPadding.top, greaterThanOrEqualTo(0));
    expect(initialMediaQuery.viewPadding.bottom, greaterThanOrEqualTo(0));
    if (requireAccessibilityText) {
      final effectiveScale = initialMediaQuery.textScaler.scale(16) / 16;
      expect(
        effectiveScale,
        greaterThanOrEqualTo(2),
        reason:
            'Set iOS Settings > Accessibility > Display & Text Size > '
            'Larger Text to an accessibility size before this run.',
      );
    }

    await _open(tester, '/future-preview');
    expect(find.byKey(const Key('future_preview_screen')), findsOneWidget);
    _expectRealSafeArea(tester, initialMediaQuery);
    _expectNoFlutterException(tester);
    await binding.takeScreenshot('ios-layout-future-preview-stage-1');

    for (final stage in [1, 2]) {
      final chip = find.byKey(Key('future_preview_stage_chip_$stage'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await _pumpFrames(tester, 20);
      _expectNoFlutterException(tester);
      await binding.takeScreenshot(
        'ios-layout-future-preview-stage-${stage + 1}',
      );
    }
    final graphNode = find.byKey(const Key('future_preview_graph_node_habit'));
    await tester.ensureVisible(graphNode);
    await tester.tap(graphNode);
    await _pumpFrames(tester, 12);
    expect(
      find.byKey(const Key('future_preview_node_evidence_sheet')),
      findsOneWidget,
    );
    _expectNoFlutterException(tester);
    await binding.takeScreenshot('ios-layout-future-preview-sheet');
    Navigator.of(
      tester.element(
        find.byKey(const Key('future_preview_node_evidence_sheet')),
      ),
    ).pop();
    await _pumpFrames(tester, 8);

    await _open(tester, '/archive-search');
    expect(
      find.byKey(const Key('archive-semantic-search-field')),
      findsOneWidget,
    );
    _expectRealSafeArea(tester, _mediaQuery(tester));
    _expectNoFlutterException(tester);
    await binding.takeScreenshot('ios-layout-archive-search-initial');

    await _open(tester, '/life-os/graph');
    expect(find.text('Visual Graph Canvas'), findsOneWidget);
    _expectRealSafeArea(tester, _mediaQuery(tester));
    _expectNoFlutterException(tester);
    await binding.takeScreenshot('ios-layout-life-os-graph');

    await _open(tester, '/account/create');
    expect(find.byKey(const Key('account_auth_screen')), findsOneWidget);
    _expectRealSafeArea(tester, _mediaQuery(tester));
    _expectNoFlutterException(tester);
    await binding.takeScreenshot('ios-layout-account-create');

    await _open(tester, '/subscription-review-preview');
    expect(find.text('ArchiveMe'), findsOneWidget);
    _expectRealSafeArea(tester, _mediaQuery(tester));
    _expectNoFlutterException(tester);
    await binding.takeScreenshot('ios-layout-subscription-preview');
  });
}

Future<void> _open(WidgetTester tester, String route) async {
  appRouter.go(route);
  await _pumpFrames(tester, 30);
}

Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

MediaQueryData _mediaQuery(WidgetTester tester) {
  final context = tester.element(find.byType(MaterialApp));
  return MediaQuery.of(context);
}

void _expectRealSafeArea(WidgetTester tester, MediaQueryData mediaQuery) {
  final safeAreas = find.byType(SafeArea);
  expect(safeAreas, findsWidgets);
  final padding = mediaQuery.padding;
  final renderPadding = tester.renderObject<RenderPadding>(
    find.descendant(of: safeAreas.first, matching: find.byType(Padding)).first,
  );
  final child = renderPadding.child;
  expect(child, isNotNull);
  final childRect = MatrixUtils.transformRect(
    child!.getTransformTo(null),
    Offset.zero & child.size,
  );
  expect(childRect.left, greaterThanOrEqualTo(padding.left));
  expect(childRect.top, greaterThanOrEqualTo(padding.top));
  expect(
    childRect.right,
    lessThanOrEqualTo(mediaQuery.size.width - padding.right),
  );
  expect(
    childRect.bottom,
    lessThanOrEqualTo(mediaQuery.size.height - padding.bottom),
  );
}

void _expectNoFlutterException(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'The real iOS runner reported a Flutter layout exception.',
  );
}
