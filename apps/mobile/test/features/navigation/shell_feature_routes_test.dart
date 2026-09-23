import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/core/diagnostics/sync_status_route.dart';
import 'package:archiveme_mobile/features/habits/habits_dashboard_route.dart';
import 'package:archiveme_mobile/features/memos/archive_home_host.dart';
import 'package:archiveme_mobile/features/navigation/habit_velocity_summary_card.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('chat, habits, and system health are registered with a transition', () {
    for (final path in [
      V1RouteRegistry.chatPath,
      V1RouteRegistry.habitsPath,
      V1RouteRegistry.syncStatusPath,
    ]) {
      final route = _goRoute(appRouter.configuration.routes, path);
      expect(route, isNotNull, reason: path);
      expect(route!.pageBuilder, isNotNull, reason: path);
      expect(V1NavigationGuard.isAllowed(path), isTrue, reason: path);
      expect(V1NavigationGuard.redirectFor(path), isNull, reason: path);
    }
  });

  testWidgets('system health and the habit dashboard open from their routes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SyncStatusRoute()));
    expect(find.byKey(const Key('system_diagnostics_screen')), findsOneWidget);
    expect(find.text('System health'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: HabitsDashboardRoute()));
    await tester.pump();
    expect(find.byKey(const Key('habits_dashboard_screen')), findsOneWidget);
    expect(find.text('+ Log Habit'), findsOneWidget);
  });

  testWidgets('the archive tab offers chat and habit velocity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ArchiveHomeHost(archive: Text('Archive body')),
      ),
    );

    expect(find.byKey(const Key('archive_chat_entry')), findsOneWidget);
    expect(
      find.byKey(const Key('habit_velocity_summary_card')),
      findsOneWidget,
    );
    expect(find.text('Habit velocity and trends'), findsOneWidget);

    await tester.tap(find.byKey(const Key('life_memos_tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit_velocity_summary_card')), findsNothing);
  });

  testWidgets('account preferences include wearable sync and system health', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountScreen(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('wearable_settings_tile')), findsOneWidget);
    expect(find.text('Battery-friendly background sync'), findsOneWidget);
    expect(find.byKey(const Key('account_system_health_tile')), findsOneWidget);
    expect(find.text('System Health & Diagnostics'), findsOneWidget);
  });

  testWidgets('the habit summary card is a tappable row', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HabitVelocitySummaryCard())),
    );
    expect(
      find.text('Consistency, streaks, and logged moments'),
      findsOneWidget,
    );
  });
}

GoRoute? _goRoute(List<RouteBase> routes, String path) {
  for (final route in routes) {
    if (route is GoRoute && route.path == path) return route;
    final nested = _goRoute(route.routes, path);
    if (nested != null) return nested;
  }
  return null;
}
