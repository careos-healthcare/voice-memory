import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

void main() {
  setUp(() => ProductAnalytics.resetForTest());

  test('trackStrings does not throw without Firebase', () async {
    await ProductAnalytics.trackStrings('archive_why_opened', {
      'kind': 'belief',
    });
  });

  test('sanitize event name strips invalid characters', () async {
    await ProductAnalytics.track('Archive Why Opened!!');
  });
}
