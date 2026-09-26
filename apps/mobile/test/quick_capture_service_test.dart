import 'package:archiveme_mobile/features/quick_capture/quick_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick capture audit stays quiet while the flag is off', () {
    QuickCaptureService.auditQuickCaptureCapabilities();
    final matrix = QuickCaptureService.supportMatrix(
      isIos: true,
      major: 18,
      watch: false,
    );
    expect(matrix['siri'], isTrue);
    expect(matrix['shortcuts'], isTrue);
    expect(matrix['actionButton'], isTrue);
    expect(matrix['controlCenter'], isTrue);
    expect(matrix['homeWidget'], isTrue);
    expect(matrix['lockWidget'], isTrue);
    expect(matrix['liveActivity'], isTrue);
    expect(matrix['watchCompanion'], isFalse);
  });

  test('iOS 17 includes the Action Button and omits Control Center', () {
    final matrix = QuickCaptureService.supportMatrix(
      isIos: true,
      major: 17,
      watch: false,
    );
    expect(matrix['actionButton'], isTrue);
    expect(matrix['controlCenter'], isFalse);
  });

  test('older iOS builds omit Control Center and the Action Button', () {
    final matrix = QuickCaptureService.supportMatrix(
      isIos: true,
      major: 16,
      watch: true,
    );
    expect(matrix['actionButton'], isFalse);
    expect(matrix['controlCenter'], isFalse);
    expect(matrix['liveActivity'], isTrue);
    expect(matrix['watchCompanion'], isTrue);
  });
}
