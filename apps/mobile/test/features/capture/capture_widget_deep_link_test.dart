import 'package:archiveme_mobile/features/capture/deep_link/capture_widget_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaptureWidgetDeepLinkHandler', () {
    test('recognizes archiveme://record host form', () {
      expect(
        CaptureWidgetDeepLinkHandler.isRecordDeepLink(
          Uri.parse('archiveme://record'),
        ),
        isTrue,
      );
    });

    test('recognizes archiveme:///record path form', () {
      expect(
        CaptureWidgetDeepLinkHandler.isRecordDeepLink(
          Uri.parse('archiveme:///record'),
        ),
        isTrue,
      );
    });

    test('rejects unrelated schemes', () {
      expect(
        CaptureWidgetDeepLinkHandler.isRecordDeepLink(
          Uri.parse('https://example.com/record'),
        ),
        isFalse,
      );
    });
  });
}
