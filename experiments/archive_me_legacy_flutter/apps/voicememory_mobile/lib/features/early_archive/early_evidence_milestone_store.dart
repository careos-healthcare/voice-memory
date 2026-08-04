import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Local-only flags for guided early-evidence captures (trigger / helpful action).
class EarlyEvidenceMilestoneStore {
  EarlyEvidenceMilestoneStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _triggerKey = 'earlyEvidenceTriggerCaptured';
  static const _helpfulKey = 'earlyEvidenceHelpfulActionCaptured';

  static EarlyEvidenceMilestoneStore instance() =>
      EarlyEvidenceMilestoneStore(AppServices.instance.prefs);

  static EarlyEvidenceMilestoneStore forPrefs(MobilePrefsStore prefs) =>
      EarlyEvidenceMilestoneStore(prefs);

  Future<bool> get triggerCaptured async =>
      (await _prefs.readString(_triggerKey)) == '1';

  Future<bool> get helpfulActionCaptured async =>
      (await _prefs.readString(_helpfulKey)) == '1';

  Future<void> markTriggerCaptured() async {
    await _prefs.writeString(_triggerKey, '1');
  }

  Future<void> markHelpfulActionCaptured() async {
    await _prefs.writeString(_helpfulKey, '1');
  }

  @visibleForTesting
  static bool testTriggerCaptured = false;

  @visibleForTesting
  static bool testHelpfulActionCaptured = false;

  @visibleForTesting
  static bool useTestFlags = false;

  Future<bool> readTriggerCaptured() async =>
      useTestFlags ? testTriggerCaptured : triggerCaptured;

  Future<bool> readHelpfulActionCaptured() async =>
      useTestFlags ? testHelpfulActionCaptured : helpfulActionCaptured;

  @visibleForTesting
  static void resetForTest() {
    useTestFlags = false;
    testTriggerCaptured = false;
    testHelpfulActionCaptured = false;
  }
}
