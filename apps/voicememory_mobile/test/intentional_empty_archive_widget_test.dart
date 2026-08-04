import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.textContaining(ArchiveTabFourStateCopy.emptyBody),
      findsOneWidget,
    );
    expect(find.text(ArchiveTabFourStateCopy.recordMomentCta), findsOneWidget);
    expect(find.textContaining('freedom, but I keep choosing'), findsNothing);
    expect(find.textContaining('VoiceMemory'), findsNothing);
    expect(find.textContaining('Your archive is ready'), findsNothing);
  });
}
