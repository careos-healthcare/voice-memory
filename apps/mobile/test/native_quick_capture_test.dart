import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/features/capture/native_quick_capture.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native quick capture stays off', () {
    expect(V1CapabilityRegistry.nativeQuickCapture, isFalse);
    expect(
      NativeQuickCapture.autostartRequested({'autostart': '1'}),
      isFalse,
    );
    expect(
      NativeQuickCapture.textEntryRequested({'autostart': '1', 'input': 'text'}),
      isFalse,
    );
    expect(NativeQuickCapture.stopRequested({'stop': '1'}), isFalse);
    final resolved = resolveInstantCaptureDeepLink(
      Uri.parse('voicememory://record?autostart=1'),
    );
    expect(resolved, CaptureDeepLinkUris.recordRoute);
  });
}
