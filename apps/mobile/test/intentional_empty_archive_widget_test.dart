import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text(VisibleArchiveProofCopy.patternsEmptyPreviewTitle),
      findsOneWidget,
    );
    expect(
      find.text(VisibleArchiveProofCopy.patternsEmptyPreviewBody),
      findsOneWidget,
    );
    expect(
      find.text(VisibleArchiveProofCopy.patternsEmptyPreviewCta),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsOneWidget);
    expect(find.textContaining('freedom, but I keep choosing'), findsNothing);
    expect(find.textContaining('VoiceMemory'), findsNothing);
    expect(find.textContaining('Your archive is ready'), findsNothing);
  });
}