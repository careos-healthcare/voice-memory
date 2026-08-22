import 'package:archiveme_mobile/config/archive_tool_routes.dart';
import 'package:archiveme_mobile/config/production_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('belief survival is deferred and hidden from nav', () {
    expect(
      ArchiveToolRoutes.isDeferred('/archive-tool/belief-survival'),
      isTrue,
    );
    expect(
      ProductionNavigation.isNavRouteVisible('/archive-tool/belief-survival'),
      isFalse,
    );
    expect(
      ProductionNavigation.redirectAwayFromIncomplete(
        '/archive-tool/belief-survival',
      ),
      '/archive-belief',
    );
  });

  test('pattern review remains visible in release', () {
    expect(ProductionNavigation.isNavRouteVisible('/blind-spots'), isTrue);
  });
}