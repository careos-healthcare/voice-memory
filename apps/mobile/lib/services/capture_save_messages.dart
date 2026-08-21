import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// User-facing copy for capture / sync — local success is never overridden by backend errors.
class CaptureSaveMessages {
  CaptureSaveMessages._();

  static const String recordingSavedLocally = 'Recording saved locally';

  static const String savedPrivatelyOnDevice =
      ConsumerUiCopy.savedPrivatelyOnDevice;

  static const String addAnotherMomentTomorrow =
      ConsumerUiCopy.addAnotherMomentTomorrow;

  static const String syncNotAvailableTestFlight =
      ConsumerUiCopy.syncNotAvailableTestFlight;

  static const String syncUnavailableOffline =
      'Sync will resume when you are back online.';

  static String syncNoteFor(Object error) {
    if (error is ApiFailure) {
      return syncNoteFor(error.toApiException());
    }
    if (error is BackendNotConfiguredException) {
      return syncNotAvailableTestFlight;
    }
    if (error is ApiException && error.code == 'BACKEND_NOT_CONFIGURED') {
      return syncNotAvailableTestFlight;
    }
    if (error is SocketException ||
        (error is ApiException && error.code == 'OFFLINE')) {
      return syncUnavailableOffline;
    }
    return savedPrivatelyOnDevice;
  }
}