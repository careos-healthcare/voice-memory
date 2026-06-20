import 'package:flutter/foundation.dart';

/// Keeps cold start lightweight — defers archive/memory engines and billing
/// until the UI is stable or the relevant tab is opened.
abstract class StartupLightMode {
  StartupLightMode._();

  static const enabled = bool.fromEnvironment(
    'ARCHIVEME_STARTUP_LIGHT_MODE',
    defaultValue: true,
  );

  static bool? _testOverride;
  static bool _firstFrameComplete = false;
  static bool _uiStable = false;
  static bool _billingLoadAllowed = false;
  static bool _archiveEnginesAllowed = false;
  static bool _loggedEnabled = false;
  static bool _loggedBillingDeferred = false;
  static bool _loggedRecordArchiveBlocked = false;
  static final List<VoidCallback> _uiStableListeners = [];
  static final List<VoidCallback> _archiveEngineListeners = [];

  static bool get isActive => _testOverride ?? enabled;

  /// Skip thread_return / weekly_review / belief_distance / aha / retrieval on
  /// Record tab until the user opens Patterns or View archive.
  static bool get shouldSkipRecordArchiveEngines =>
      isActive && !_archiveEnginesAllowed;

  static bool get shouldDeferBilling => isActive && !_billingLoadAllowed;

  static bool get shouldDeferPatternsInitialLoad => isActive;

  static void logEnabledOnce() {
    if (_loggedEnabled) return;
    _loggedEnabled = true;
    debugPrint('ARCHIVEME_STARTUP_LIGHT_MODE enabled=$isActive');
  }

  static void logArchiveEnginesSkipped(String reason) {
    debugPrint('ARCHIVEME_STARTUP_ARCHIVE_ENGINES_SKIPPED reason=$reason');
  }

  static void logRecordStartupArchiveEnginesBlocked() {
    if (_loggedRecordArchiveBlocked) return;
    _loggedRecordArchiveBlocked = true;
    debugPrint(
      'ARCHIVEME_RECORD_STARTUP_ARCHIVE_ENGINES_BLOCKED reason=record_tab_light_mode',
    );
  }

  static void logBillingDeferredOnce() {
    if (_loggedBillingDeferred) return;
    _loggedBillingDeferred = true;
    debugPrint('ARCHIVEME_STARTUP_BILLING_DEFERRED');
  }

  static void logReady({required int entryCount}) {
    debugPrint('ARCHIVEME_STARTUP_READY entryCount=$entryCount');
  }

  static void markFirstFrame() {
    _firstFrameComplete = true;
  }

  static void markUiStable() {
    _firstFrameComplete = true;
    _uiStable = true;
    allowBillingLoad();
    final listeners = List<VoidCallback>.from(_uiStableListeners);
    _uiStableListeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  static void onUiStable(VoidCallback listener) {
    if (_uiStable) {
      listener();
      return;
    }
    _uiStableListeners.add(listener);
  }

  static void onArchiveEnginesAllowed(VoidCallback listener) {
    if (_archiveEnginesAllowed) {
      listener();
      return;
    }
    _archiveEngineListeners.add(listener);
  }

  static void allowBillingLoad() {
    _billingLoadAllowed = true;
  }

  static void allowArchiveEngines(String reason) {
    if (!_archiveEnginesAllowed) {
      _archiveEnginesAllowed = true;
      debugPrint('ARCHIVEME_ARCHIVE_ENGINES_ALLOWED reason=$reason');
      final listeners = List<VoidCallback>.from(_archiveEngineListeners);
      _archiveEngineListeners.clear();
      for (final listener in listeners) {
        listener();
      }
    }
  }

  static void onAccountTabOpened() {
    allowBillingLoad();
  }

  static void onPatternsTabOpened() {
    allowBillingLoad();
    allowArchiveEngines('patterns_tab_visible');
  }

  static void onViewArchiveTapped() {
    allowArchiveEngines('view_archive_tapped');
  }

  @visibleForTesting
  static void resetForTest() {
    _testOverride = null;
    _firstFrameComplete = false;
    _uiStable = false;
    _billingLoadAllowed = false;
    _archiveEnginesAllowed = false;
    _loggedEnabled = false;
    _loggedBillingDeferred = false;
    _loggedRecordArchiveBlocked = false;
    _uiStableListeners.clear();
    _archiveEngineListeners.clear();
  }

  @visibleForTesting
  static void setEnabledForTest(bool? value) {
    _testOverride = value;
    _loggedEnabled = false;
    _loggedBillingDeferred = false;
    _loggedRecordArchiveBlocked = false;
  }

  @visibleForTesting
  static bool get isUiStableForTest => _uiStable;

  @visibleForTesting
  static bool get isBillingLoadAllowedForTest => _billingLoadAllowed;

  @visibleForTesting
  static bool get areArchiveEnginesAllowedForTest => _archiveEnginesAllowed;
}
