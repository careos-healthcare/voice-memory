import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_clean/archive_clean_section_model.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_clean_view_card.dart';

List<ArchiveCleanSection> _sampleSections() => const [
  ArchiveCleanSection(
    type: ArchiveCleanSectionType.today,
    title: 'Today',
    subtitle: 'Moments and checks from today',
    primaryCtaLabel: 'Open today',
    route: '/moments',
    count: 1,
  ),
  ArchiveCleanSection(
    type: ArchiveCleanSectionType.thisWeek,
    title: 'This week',
    subtitle: 'Moments from the last 7 days',
    primaryCtaLabel: 'Open this week',
    route: '/moments',
    count: 3,
  ),
  ArchiveCleanSection(
    type: ArchiveCleanSectionType.thisPattern,
    title: 'This pattern',
    subtitle: 'Taking on too much before checking in',
    primaryCtaLabel: 'Open pattern',
    route: '/pattern-profile',
  ),
  ArchiveCleanSection(
    type: ArchiveCleanSectionType.askArchive,
    title: 'Ask my Archive',
    subtitle: 'Find what ArchiveMe remembers.',
    primaryCtaLabel: 'Search moments',
    route: '/ask-archive',
  ),
  ArchiveCleanSection(
    type: ArchiveCleanSectionType.olderMoments,
    title: 'Older moments',
    subtitle: 'Moments from before this week',
    primaryCtaLabel: 'Find older moments',
    route: '/moments',
    count: 2,
  ),
];

void main() {
  testWidgets('renders title, subtitle, and all available sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveCleanViewCard(
            sections: _sampleSections(),
            onSectionTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Your archive'), findsOneWidget);
    expect(find.text('Find moments by day, week, or pattern.'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This pattern'), findsOneWidget);
    expect(find.text('Ask my Archive'), findsOneWidget);
    expect(find.text('Older moments'), findsOneWidget);
    expect(find.text('Search moments'), findsOneWidget);
  });

  testWidgets('tapping row calls callback with section', (tester) async {
    ArchiveCleanSection? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveCleanViewCard(
            sections: _sampleSections(),
            onSectionTap: (section) => tapped = section,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ask my Archive'));
    await tester.pump();

    expect(tapped?.type, ArchiveCleanSectionType.askArchive);
    expect(tapped?.route, '/ask-archive');
  });

  testWidgets('tapping CTA calls callback with section', (tester) async {
    ArchiveCleanSection? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveCleanViewCard(
            sections: _sampleSections(),
            onSectionTap: (section) => tapped = section,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open pattern'));
    await tester.pump();

    expect(tapped?.type, ArchiveCleanSectionType.thisPattern);
    expect(tapped?.route, '/pattern-profile');
  });
}
