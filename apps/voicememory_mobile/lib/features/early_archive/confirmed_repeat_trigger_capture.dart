import 'package:flutter/foundation.dart';

import 'early_first_signal_copy.dart';

/// Session state for the confirmed-repeat trigger capture flow.
///
/// Armed when the user opens Record from the return prompt CTA; consumed on
/// save so normal recordings never inherit the trigger payoff.
abstract final class ConfirmedRepeatTriggerCapture {
  ConfirmedRepeatTriggerCapture._();

  static bool _armedForNextSave = false;

  /// True only for the most recent save that used the trigger guided prompt.
  static bool lastSaveWasTriggerCapture = false;

  static void armForNextSave() {
    _armedForNextSave = true;
  }

  static void armIfTriggerPrompt(String? prompt) {
    if (prompt?.trim() == EarlyFirstSignalCopy.recordTriggerGuidedPrompt) {
      armForNextSave();
    }
  }

  /// Returns true when this save should receive the trigger payoff.
  static bool resolveSave({String? capturePrompt}) {
    final armed = _armedForNextSave;
    _armedForNextSave = false;
    final promptMatches =
        capturePrompt?.trim() == EarlyFirstSignalCopy.recordTriggerGuidedPrompt;
    final saved = armed && promptMatches;
    lastSaveWasTriggerCapture = saved;
    return saved;
  }

  static void clearSaveReceipt() {
    lastSaveWasTriggerCapture = false;
  }

  @visibleForTesting
  static void resetSessionForTest() {
    _armedForNextSave = false;
    lastSaveWasTriggerCapture = false;
  }
}
