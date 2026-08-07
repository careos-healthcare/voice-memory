import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/product/v1_free_paid_capabilities.dart';

void main() {
  test('export and deletion stay free; deeper history is paid', () {
    expect(V1FreePaidCapabilities.isFree(V1Capability.export), isTrue);
    expect(V1FreePaidCapabilities.isFree(V1Capability.accountDeletion), isTrue);
    expect(V1FreePaidCapabilities.isPaid(V1Capability.deeperHistory), isTrue);
    expect(
      V1FreePaidCapabilities.requiresPro(V1Capability.deeperHistory),
      isTrue,
    );
  });
}
