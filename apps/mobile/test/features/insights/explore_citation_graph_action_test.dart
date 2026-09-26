import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/insights/explore_patterns_screen.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_notifier.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_state.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_feature_flags.dart';
import 'package:archiveme_mobile/features/insights/widgets/evidence_connection_graph_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PatternExplorationMessage _assistant({
  List<String> citedEntryIds = const [],
  String content = 'These moments share a thread.',
}) {
  return PatternExplorationMessage(
    role: PatternExplorationMessage.roleAssistant,
    content: content,
    citedEntryIds: citedEntryIds,
  );
}

Finder get _actionFinder =>
    find.text(ExplorePatternsScreen.seeHowThisConnectsLabel);

void main() {
  setUp(() {
    PatternExplorationFeatureFlags.debugOverride = true;
    UserPreferences.debugCloudSyncOverride = true;
  });

  tearDown(() {
    PatternExplorationFeatureFlags.debugOverride = null;
    UserPreferences.debugCloudSyncOverride = null;
  });

  Future<void> pumpAction(
    WidgetTester tester,
    PatternExplorationMessage message,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExploreCitationGraphAction(message: message),
          ),
        ),
      ),
    );
  }

  testWidgets('hides the action when there are no citations', (tester) async {
    await pumpAction(tester, _assistant());
    expect(_actionFinder, findsNothing);
  });

  testWidgets('hides the action when there is only one citation',
      (tester) async {
    await pumpAction(tester, _assistant(citedEntryIds: const ['only-one']));
    expect(_actionFinder, findsNothing);
  });

  testWidgets('shows the action when there are two or more citations',
      (tester) async {
    await pumpAction(
      tester,
      _assistant(citedEntryIds: const ['a', 'b']),
    );
    expect(_actionFinder, findsOneWidget);
  });

  testWidgets('hides the action when pattern exploration is gated off',
      (tester) async {
    PatternExplorationFeatureFlags.debugOverride = false;
    await pumpAction(
      tester,
      _assistant(citedEntryIds: const ['a', 'b']),
    );
    expect(_actionFinder, findsNothing);
  });

  testWidgets('opens the connection sheet from ExplorePatternsScreen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patternExplorationConversationProvider.overrideWith(
            _TwoCitationConversationNotifier.new,
          ),
        ],
        child: const MaterialApp(home: ExplorePatternsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(_actionFinder, findsOneWidget);

    await tester.tap(_actionFinder);
    await tester.pumpAndSettle();

    expect(find.byKey(EvidenceConnectionGraphSheet.sheetKey), findsOneWidget);
    expect(find.text(EvidenceConnectionGraphSheet.title), findsOneWidget);
  });
}

class _TwoCitationConversationNotifier
    extends PatternExplorationConversationNotifier {
  @override
  PatternExplorationConversationState build() {
    return const PatternExplorationConversationState(
      messages: [
        PatternExplorationMessage(
          role: PatternExplorationMessage.roleAssistant,
          content: 'These moments share a thread.',
          citedEntryIds: ['entry-a', 'entry-b'],
        ),
      ],
    );
  }
}
