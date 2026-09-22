import 'package:archiveme_mobile/core/theme/responsive_breakpoints.dart';
import 'package:archiveme_mobile/core/theme/theme_preference.dart';
import 'package:archiveme_mobile/desktop/archive_command_catalog.dart';
import 'package:archiveme_mobile/desktop/archive_command_palette.dart';
import 'package:archiveme_mobile/features/navigation/presentation/responsive_navigation_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('breakpoints split phone, tablet, and desktop', () {
    expect(ResponsiveBreakpoints.isMobile(639), isTrue);
    expect(ResponsiveBreakpoints.isTablet(640), isTrue);
    expect(ResponsiveBreakpoints.isTablet(1024), isTrue);
    expect(ResponsiveBreakpoints.isDesktop(1025), isTrue);
    expect(ResponsiveBreakpoints.mobileTouchTarget, greaterThanOrEqualTo(48));
    expect(ResponsiveBreakpoints.desktopTouchTarget, greaterThanOrEqualTo(32));
  });

  test('palette lists the primary keyboard actions', () {
    final titles = ArchiveCommandCatalog.commands.map((command) => command.title);
    expect(titles, contains('Create Entry'));
    expect(titles, contains('Search Archives'));
    expect(titles, contains('Toggle Theme'));
    expect(titles, contains('Export Data'));
    expect(titles, contains('Open Insights'));
  });

  test('toggle theme switches light and dark', () {
    final preference = ThemePreference.instance;
    preference.mode = ThemeMode.light;
    addTearDown(() => preference.mode = ThemeMode.system);
    preference.toggle();
    expect(preference.mode, ThemeMode.dark);
    preference.toggle();
    expect(preference.mode, ThemeMode.light);
  });

  testWidgets('narrow width uses tabs and wide width uses a sidebar', (
    tester,
  ) async {
    Future<void> pump(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveNavigationWrapper(
            selectedIndex: 0,
            onSelected: (_) {},
            destinations: const [
              NavigationDestination(icon: Icon(Icons.mic), label: 'Record'),
              NavigationDestination(icon: Icon(Icons.book), label: 'Archive'),
            ],
            body: const Text('Home'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pump(const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await pump(const Size(1200, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('nav_collapse_toggle')), findsOneWidget);
  });

  testWidgets('Cmd+K opens the palette and a bare k in a field does not', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: CommandPaletteHost(
          navigatorKey: navigatorKey,
          child: const Scaffold(body: TextField()),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.byKey(const Key('archive_command_palette')), findsNothing);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive_command_palette')), findsOneWidget);
    expect(find.text('Create Entry'), findsOneWidget);
  });
}
