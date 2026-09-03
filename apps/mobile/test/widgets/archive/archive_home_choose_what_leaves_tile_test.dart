import 'package:archiveme_mobile/features/archive/ui/remote_processing_choice_copy.dart';
import 'package:archiveme_mobile/features/archive/ui/trust_status_footer_copy.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_dashboard_scroll_view.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/archive_home_choose_what_leaves_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('ArchiveHomeChooseWhatLeavesTile', () {
    testWidgets('names the privacy-card choice and reports the tap', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHomeChooseWhatLeavesTile(onTap: () => tapped = true),
          ),
        ),
      );

      expect(
        find.text(RemoteProcessingChoiceCopy.chooseWhatLeavesTitle),
        findsOneWidget,
      );
      expect(
        find.text(PrivacyScreenCopy.whereWordsGoTitle),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ArchiveHomeChooseWhatLeavesTile.tileKey));
      expect(tapped, isTrue);
    });
  });

  group('ArchiveDashboardScrollView', () {
    testWidgets('keeps the tile on Archive Home and opens the trust centre', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: ArchiveDashboardScrollView(
                controller: controller,
                feed: const ArchiveFeedState(
                  loadState: ArchiveBeliefLoadState.loaded,
                ),
                loadState: ArchiveBeliefLoadState.loaded,
                visibleEntries: const [],
                showChangesUnavailable: false,
                onRefresh: () async {},
                onEntryTap: (_) {},
                onQueryChanged: (_) {},
                onCapture: () {},
              ),
            ),
          ),
          GoRoute(
            path: '/privacy-trust-centre',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('PRIVACY CENTRE'))),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('SETTINGS'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ArchiveHomeChooseWhatLeavesTile.tileKey),
        findsOneWidget,
      );
      expect(find.text('SETTINGS'), findsNothing);
      expect(find.text(TrustStatusFooterCopy.storedOnDevice), findsOneWidget);

      await tester.tap(find.byKey(ArchiveHomeChooseWhatLeavesTile.tileKey));
      await tester.pumpAndSettle();

      expect(find.text('PRIVACY CENTRE'), findsOneWidget);
      expect(find.text('SETTINGS'), findsNothing);
    });
  });
}
