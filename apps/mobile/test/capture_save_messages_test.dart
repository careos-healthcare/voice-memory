import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:flutter_test/flutter_test.dart';

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