import 'package:flutter/foundation.dart';

import 'early_first_signal_copy.dart';

/// Session state for the confirmed-repeat helpful-action capture flow.
///
/// Armed when the user opens Record from the change-notice CTA; consumed on
/// save so normal recordings never inherit the helpful-action payoff.
abstract final class ConfirmedRepeatHelpfulActionCapture {
  ConfirmedRepeatHelpfulActionCapture._();

  static bool _armedForNextSave = false;

  /// True only for the most recent save that used the helpful-action prompt.
  static bool lastSaveWasHelpfulActionCapture = false;

  static void armForNextSave() {
    _armedForNextSave = true;
  }

  static void armIfHelpfulPrompt(String? prompt) {
    if (prompt?.trim() == EarlyFirstSignalCopy.recordWhatHelpedGuidedPrompt) {
      armForNextSave();
    }
  }

  /// Returns true when this save should receive the helpful-action payoff.
  static bool resolveSave({String? capturePrompt}) {
    final armed = _armedForNextSave;
    _armedForNextSave = false;
    final promptMatches =
        capturePrompt?.trim() ==
        EarlyFirstSignalCopy.recordWhatHelpedGuidedPrompt;
    final saved = armed && promptMatches;
    lastSaveWasHelpfulActionCapture = saved;
    return saved;
  }

  static void clearSaveReceipt() {
    lastSaveWasHelpfulActionCapture = false;
  }

  @visibleForTesting
  static void resetSessionForTest() {
    _armedForNextSave = false;
    lastSaveWasHelpfulActionCapture = false;
  }
}
