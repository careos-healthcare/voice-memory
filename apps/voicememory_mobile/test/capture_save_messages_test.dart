import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';

void main() {
  test('backend not configured uses TestFlight-safe sync copy', () {
    expect(
      CaptureSaveMessages.syncNoteFor(BackendNotConfiguredException()),
      ConsumerUiCopy.syncNotAvailableTestFlight,
    );
    expect(
      CaptureSaveMessages.recordingSavedLocally,
      'Recording saved locally',
    );
  });
}
