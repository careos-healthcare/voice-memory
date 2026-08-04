import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/screens/export_screen.dart';

import 'support/accessibility_matrix.dart';

void main() {
  testWidgets('offers explicit readable and full archive choices', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExportScreen()));

    expect(find.byKey(const Key('export_readable_archive')), findsOneWidget);
    expect(find.text('Readable archive (no audio bytes)'), findsOneWidget);
    expect(find.byKey(const Key('export_full_archive')), findsOneWidget);
    expect(
      find.text('Full archive (includes available audio)'),
      findsOneWidget,
    );
    expect(find.textContaining('reference-only'), findsNothing);
    expect(
      find.textContaining('destination you choose controls the plaintext'),
      findsOneWidget,
    );
  });

  testWidgets('2x text preserves order, labels, keyboard, and 48dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpUnderProfile(
      tester,
      const AccessibilityProfile(
        name: 'export 2x',
        size: Size(390, 844),
        brightness: Brightness.light,
        textScale: 2,
      ),
      child: const ExportScreen(),
    );

    expectNoOverflow(tester);
    expectTapTargets(tester, minimum: 48);
    final order = semanticReadingOrder(tester);
    expectAnnouncedBefore(
      order,
      'Readable archive (no audio bytes)',
      'Full archive (includes available audio)',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(primaryFocus, isNotNull);
    semantics.dispose();
  });
}
