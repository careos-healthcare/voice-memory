import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_memory_empty_preview_card.dart';

void main() {
  testWidgets('shows What ArchiveMe will remember preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ArchiveMemoryEmptyPreviewCard(onRecord: () {})),
      ),
    );
    expect(find.text(ConsumerUiCopy.archiveMemoryPreviewTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.archiveMemoryPreviewBody), findsOneWidget);
    for (final bullet in ConsumerUiCopy.archiveMemoryPreviewBullets) {
      expect(find.text(bullet), findsOneWidget);
    }
  });

  testWidgets('preview CTA fires onRecord', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ArchiveMemoryEmptyPreviewCard(onRecord: () => tapped = true),
        ),
      ),
    );
    await tester.tap(find.text(ConsumerUiCopy.archiveMemoryPreviewCta));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
