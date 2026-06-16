import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  testWidgets('IntentionalEmptyArchiveView delegates to patterns empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: IntentionalEmptyArchiveView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsEarlyStateBody), findsOneWidget);
    expect(
      find.text('ArchiveMe connects moments that keep showing up'),
      findsOneWidget,
    );
    expect(find.textContaining('No judgement'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsEmptyCta), findsOneWidget);
    expect(find.textContaining('freedom, but I keep choosing'), findsNothing);
    expect(find.textContaining('VoiceMemory'), findsNothing);
    expect(find.textContaining('Your archive is ready'), findsNothing);
  });
}
