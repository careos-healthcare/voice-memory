import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/archive_memory/memory_quality_coordinator.dart';
import 'package:archiveme_mobile/features/archive_memory/memory_quality_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load returns hidden when AppServices is not initialized', () async {
    final quality = await MemoryQualityCoordinator.load();
    expect(quality, MemoryQuality.hidden);
    expect(quality.shouldShow, isFalse);
  });

  test('screenshot sample shows clear pattern chip data', () {
    final sample = ScreenshotSampleData.memoryQualitySample;
    expect(sample.label, 'Clear pattern');
    expect(sample.level, MemoryQualityLevel.clearPattern);
    expect(sample.shouldShow, isTrue);
    expect(sample.momentCount, 8);
  });
}