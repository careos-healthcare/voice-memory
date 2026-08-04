import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/config/v1_navigation_guard.dart';
import 'package:voicememory_mobile/screens/archive_tools_screen.dart';
import 'package:voicememory_mobile/widgets/accessibility/accessible_primary_surface.dart';

Finder semanticsWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}

void main() {
  testWidgets('archive tools consolidate features into two hubs', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const MaterialApp(home: ArchiveToolsScreen()));

    expect(find.text('Life Story'), findsWidgets);
    expect(find.text('Archive Intelligence'), findsOneWidget);
    expect(find.byType(AccessiblePrimarySurface), findsOneWidget);
    expect(find.byType(FocusTraversalGroup), findsWidgets);
    expect(semanticsWithLabel('Open Life Story'), findsOneWidget);
    expect(semanticsWithLabel('Open chapters and identity'), findsOneWidget);
    expect(semanticsWithLabel('Open story graph'), findsOneWidget);

    await tester.tap(find.text('Archive Intelligence'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('life_os_graph_search_bar')), findsOneWidget);
    expect(
      semanticsWithLabel('Search personal knowledge graph'),
      findsOneWidget,
    );
    expect(semanticsWithLabel('Open Archive Intelligence'), findsOneWidget);
    expect(semanticsWithLabel('Search archive intelligence'), findsOneWidget);
    expect(semanticsWithLabel('Open change review'), findsOneWidget);
    expect(semanticsWithLabel('Open capacity signals'), findsOneWidget);
    expect(semanticsWithLabel('Open archive facts'), findsOneWidget);
    semantics.dispose();
  });

  test('experimental hubs are blocked while graph stays secondary', () {
    for (final route in {
      ArchiveToolsScreen.route,
      '/weekly-report',
      '/capacity-loop',
      '/details',
      '/archive-analyst',
      '/life-os',
    }) {
      expect(V1NavigationGuard.isAllowed(route), isFalse, reason: route);
    }
    expect(V1NavigationGuard.isAllowed('/life-os/graph'), isTrue);
  });
}
