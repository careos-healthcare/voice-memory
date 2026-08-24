import 'package:archiveme_mobile/features/activation/belief_evidence_trail.dart';
import 'package:archiveme_mobile/features/post_save/post_save_focused_actions_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/screens/belief_evidence_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/post_save_focused_actions_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('PostSaveFocusedActionsBar', () {
    testWidgets('Record if it happens again routes to /record', (tester) async {
      var recordOpened = false;
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: PostSaveFocusedActionsBar(
                onViewEvidence: () {},
                onViewPatterns: () {},
                onAddOneMoreMoment: () {
                  recordOpened = true;
                  context.go('/record');
                },
              ),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) => const Scaffold(
              body: Text('RECORD_SCREEN', key: Key('record_screen_marker')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(PostSaveFocusedActionsCopy.addOneMoreMoment));
      await tester.pumpAndSettle();

      expect(recordOpened, isTrue);
      expect(find.byKey(const Key('record_screen_marker')), findsOneWidget);
    });

    testWidgets('View evidence pushes belief evidence route', (tester) async {
      var evidenceOpened = false;
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: PostSaveFocusedActionsBar(
                onViewEvidence: () {
                  evidenceOpened = true;
                  context.push(BeliefEvidenceNavigation.route);
                },
                onViewPatterns: () {},
                onAddOneMoreMoment: () {},
              ),
            ),
          ),
          GoRoute(
            path: BeliefEvidenceNavigation.route,
            builder: (context, state) => BeliefEvidenceScreen(
              previewTrail: BeliefEvidenceTrail.insufficient(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(PostSaveFocusedActionsCopy.viewEvidence));
      await tester.pumpAndSettle();

      expect(evidenceOpened, isTrue);
      expect(
        find.byKey(const Key('belief_evidence_screen_title')),
        findsOneWidget,
      );
    });
  });
}