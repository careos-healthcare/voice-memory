import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveInstantCaptureDeepLink', () {
    test('maps archiveme://record to background capture route', () {
      final resolved = resolveInstantCaptureDeepLink(
        Uri.parse('archiveme://record'),
      );

      expect(resolved, isNotNull);
      expect(resolved, contains('${CaptureDeepLinkUris.recordRoute}?'));
      expect(resolved, contains('autostart=1'));
      expect(resolved, contains('background=1'));
      expect(resolved, contains('instant=1'));
    });
  });
}
