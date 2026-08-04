import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive/presentation/widgets/archive_moments_list_view.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';

void main() {
  ArchiveMomentRecord moment({required String id, required String savedWords}) {
    return ArchiveMomentRecord(
      id: id,
      createdAt: DateTime(2026, 7, 24, 9, 5),
      savedWords: savedWords,
    );
  }

  Widget harness({
    required List<ArchiveMomentRecord> moments,
    ValueChanged<ArchiveMomentRecord>? onTap,
    ValueChanged<ArchiveMomentRecord>? onDismiss,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ArchiveMomentsListView(
          moments: moments,
          onMomentTapped: onTap ?? (_) {},
          onMomentDismissed: onDismiss ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('shows manifesto-aligned empty state', (tester) async {
    await tester.pumpWidget(harness(moments: const []));

    expect(
      find.byKey(const Key('archive_moments_empty_state')),
      findsOneWidget,
    );
    expect(find.text('No moments saved yet.'), findsOneWidget);
    expect(find.textContaining('One sentence is enough.'), findsOneWidget);
    expect(find.textContaining('journal entry'), findsNothing);
    expect(find.textContaining('reflection'), findsNothing);
  });

  testWidgets('renders saved words, timestamp, and stable key', (tester) async {
    final savedMoment = moment(
      id: 'moment-1',
      savedWords: 'I noticed the same pressure before answering.',
    );

    await tester.pumpWidget(harness(moments: [savedMoment]));

    expect(find.byKey(const Key('archive_moments_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('moment_moment-1')), findsOneWidget);
    expect(
      find.text('I noticed the same pressure before answering.'),
      findsOneWidget,
    );
    expect(find.text('7/24/2026 • 9:05'), findsOneWidget);
  });

  testWidgets('uses an accessible fallback for empty saved words', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        moments: [moment(id: 'audio', savedWords: '  ')],
      ),
    );

    expect(find.text('Saved audio moment'), findsOneWidget);
  });

  testWidgets('forwards the tapped moment', (tester) async {
    final savedMoment = moment(id: 'tap-me', savedWords: 'A saved thought');
    ArchiveMomentRecord? tapped;
    await tester.pumpWidget(
      harness(moments: [savedMoment], onTap: (moment) => tapped = moment),
    );

    await tester.tap(find.text('A saved thought'));

    expect(tapped, same(savedMoment));
  });

  testWidgets('supports swipe-to-dismiss and forwards the removed moment', (
    tester,
  ) async {
    final initialMoment = moment(
      id: 'dismiss-me',
      savedWords: 'Remove this moment',
    );
    final visibleMoments = [initialMoment];
    ArchiveMomentRecord? dismissed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ArchiveMomentsListView(
                moments: visibleMoments,
                onMomentTapped: (_) {},
                onMomentDismissed: (moment) {
                  dismissed = moment;
                  setState(() => visibleMoments.remove(moment));
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('moment_dismiss-me')),
      const Offset(-800, 0),
    );
    await tester.pumpAndSettle();

    expect(dismissed, same(initialMoment));
    expect(visibleMoments, isEmpty);
    expect(find.text('No moments saved yet.'), findsOneWidget);
  });
}
