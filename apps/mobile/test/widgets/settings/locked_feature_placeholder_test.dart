import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/widgets/onboarding/onboarding_progressive_disclosure_card.dart';
import 'package:archiveme_mobile/widgets/settings/advanced_tools_settings_section.dart';
import 'package:archiveme_mobile/widgets/settings/locked_feature_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('locked placeholder shows remaining moments and days', (
    tester,
  ) async {
    const snapshot = UserMilestoneSnapshot(
      journalEntryCount: 1,
      daysActive: 1,
      activeDayKeys: {'2026-09-21'},
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LockedFeaturePlaceholder(
            title: ProgressiveDisclosureCopy.vectorTitle,
            subtitle: ProgressiveDisclosureCopy.vectorSubtitle,
            surface: ProgressiveSurface.vectorRetrievalHyperparameters,
            snapshot: snapshot,
          ),
        ),
      ),
    );

    expect(find.text(ProgressiveDisclosureCopy.vectorTitle), findsOneWidget);
    expect(
      find.byKey(
        const Key('locked_feature_progress_vectorRetrievalHyperparameters'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('more saved moment'), findsOneWidget);
    expect(find.textContaining('more active day'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('onboarding card shows every advanced tool locked', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnboardingProgressiveDisclosureCard(),
        ),
      ),
    );

    expect(
      find.byKey(const Key('onboarding_progressive_disclosure_card')),
      findsOneWidget,
    );
    expect(
      find.text(ProgressiveDisclosureCopy.onboardingTitle),
      findsOneWidget,
    );
    expect(find.byType(LockedFeaturePlaceholder), findsNWidgets(3));
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('settings section keeps beginners on placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdvancedToolsSettingsSection(
            initialSnapshot: UserMilestoneSnapshot.empty,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('settings_advanced_tools_section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('advanced_tools_locked_beliefShiftGraphs')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('advanced_tools_locked_vectorRetrievalHyperparameters'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('advanced_tools_locked_deepRagConfiguration')),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('settings section reveals knobs after milestones', (
    tester,
  ) async {
    const unlocked = UserMilestoneSnapshot(
      journalEntryCount: 8,
      daysActive: 6,
      activeDayKeys: {
        '2026-09-16',
        '2026-09-17',
        '2026-09-18',
        '2026-09-19',
        '2026-09-20',
        '2026-09-21',
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdvancedToolsSettingsSection(initialSnapshot: unlocked),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('advanced_tools_unlocked_beliefShiftGraphs')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('advanced_search_rrf_k')), findsOneWidget);
    expect(
      find.byKey(const Key('advanced_search_candidate_limit')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('advanced_search_rag_chunks')), findsOneWidget);
    expect(find.byType(LockedFeaturePlaceholder), findsNothing);
  });
}
