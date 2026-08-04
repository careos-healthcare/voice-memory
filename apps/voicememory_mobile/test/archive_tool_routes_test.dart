import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/archive_tool_routes.dart';
import 'package:voicememory_mobile/config/production_navigation.dart';

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

  test('self-discovery center is excluded from focused V1 navigation', () {
    expect(ProductionNavigation.isNavRouteVisible('/self-discovery'), isFalse);
    expect(
      ProductionNavigation.redirectAwayFromIncomplete('/self-discovery'),
      '/archive-belief',
    );
  });
}
