import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// One device/preference combination a retained V1 surface must survive.
class AccessibilityProfile {
  const AccessibilityProfile({
    required this.name,
    required this.size,
    required this.brightness,
    required this.textScale,
    this.reduceMotion = false,
  });

  final String name;
  final Size size;
  final Brightness brightness;
  final double textScale;
  final bool reduceMotion;

  /// Narrow phone, large phone and tablet, in both brightnesses, at normal and
  /// maximum practical text scaling, plus a reduced-motion pass.
  static const matrix = <AccessibilityProfile>[
    AccessibilityProfile(
      name: 'narrow phone, light',
      size: Size(320, 640),
      brightness: Brightness.light,
      textScale: 1,
    ),
    AccessibilityProfile(
      name: 'narrow phone, dark, maximum text',
      size: Size(320, 640),
      brightness: Brightness.dark,
      textScale: maximumPracticalTextScale,
    ),
    AccessibilityProfile(
      name: 'large phone, light, maximum text',
      size: Size(430, 932),
      brightness: Brightness.light,
      textScale: maximumPracticalTextScale,
    ),
    AccessibilityProfile(
      name: 'large phone, dark',
      size: Size(430, 932),
      brightness: Brightness.dark,
      textScale: 1,
    ),
    AccessibilityProfile(
      name: 'tablet, light',
      size: Size(834, 1194),
      brightness: Brightness.light,
      textScale: 1.3,
    ),
    AccessibilityProfile(
      name: 'tablet, dark, reduced motion',
      size: Size(834, 1194),
      brightness: Brightness.dark,
      textScale: 1,
      reduceMotion: true,
    ),
  ];

  /// The largest scale a user can reach through the OS accessibility settings
  /// that we commit to supporting without clipping.
  static const maximumPracticalTextScale = 2.0;
}

/// Pumps [child] under [profile] with the matching media query and theme.
Future<void> pumpUnderProfile(
  WidgetTester tester,
  AccessibilityProfile profile, {
  required Widget child,
  ThemeData? light,
  ThemeData? dark,
}) async {
  tester.view.physicalSize = profile.size * tester.view.devicePixelRatio;
  tester.view.devicePixelRatio = tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: light,
      darkTheme: dark,
      themeMode: profile.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: profile.size,
          platformBrightness: profile.brightness,
          textScaler: TextScaler.linear(profile.textScale),
          disableAnimations: profile.reduceMotion,
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fails when any rendered box overflows its parent.
void expectNoOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: 'Layout overflowed: $exception');
}

/// Every interactive target must be reachable by an imprecise touch.
void expectTapTargets(WidgetTester tester, {double minimum = 44}) {
  final failures = <String>[];
  for (final type in <Type>[
    TextButton,
    FilledButton,
    OutlinedButton,
    IconButton,
    InkWell,
  ]) {
    for (final element in find.byType(type).evaluate()) {
      final finder = find.byWidget(element.widget);
      if (finder.evaluate().isEmpty) continue;
      final size = tester.getSize(finder);
      if (size.height + 0.01 < minimum || size.width + 0.01 < minimum) {
        failures.add('$type is ${size.width}x${size.height}');
      }
    }
  }
  expect(failures, isEmpty, reason: failures.join('\n'));
}

/// Reading order as a screen reader would traverse it.
List<String> semanticReadingOrder(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final text = data.label.trim().isNotEmpty
        ? data.label.trim()
        : data.value.trim();
    if (text.isNotEmpty) labels.add(text);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return labels;
}

/// Asserts [before] is announced before [after].
void expectAnnouncedBefore(List<String> order, Pattern before, Pattern after) {
  final beforeIndex = order.indexWhere((label) => label.contains(before));
  final afterIndex = order.indexWhere((label) => label.contains(after));
  expect(beforeIndex, isNonNegative, reason: 'missing "$before" in $order');
  expect(afterIndex, isNonNegative, reason: 'missing "$after" in $order');
  expect(
    beforeIndex,
    lessThan(afterIndex),
    reason: '"$before" must be announced before "$after". Order: $order',
  );
}
