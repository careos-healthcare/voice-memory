import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// User-controlled resurfacing preference — never inferred from content.
enum MemorySurfacingMode {
  normal('normal'),
  sensitive('sensitive'),
  doNotSurface('do_not_surface');

  const MemorySurfacingMode(this.id);

  final String id;

  String get label => switch (this) {
    MemorySurfacingMode.normal => MemorySurfacingCopy.normalLabel,
    MemorySurfacingMode.sensitive => MemorySurfacingCopy.sensitiveLabel,
    MemorySurfacingMode.doNotSurface => MemorySurfacingCopy.doNotSurfaceLabel,
  };

  String get helper => switch (this) {
    MemorySurfacingMode.normal => MemorySurfacingCopy.normalHelper,
    MemorySurfacingMode.sensitive => MemorySurfacingCopy.sensitiveHelper,
    MemorySurfacingMode.doNotSurface => MemorySurfacingCopy.doNotSurfaceHelper,
  };

  bool get showsSensitiveReceipt => this == MemorySurfacingMode.sensitive;

  bool get showsDoNotSurfaceReceipt => this == MemorySurfacingMode.doNotSurface;

  bool get blocksProactiveResurfacing =>
      this == MemorySurfacingMode.doNotSurface;

  bool get limitsProactiveIntensity => this != MemorySurfacingMode.normal;

  static MemorySurfacingMode fromId(String? id) {
    if (id == null || id.isEmpty) return MemorySurfacingMode.normal;
    for (final value in values) {
      if (value.id == id) return value;
    }
    return MemorySurfacingMode.normal;
  }

  static MemorySurfacingMode fromEntry(JournalEntry entry) =>
      fromId(entry.memorySurfacing);
}

/// Session selection for the next save.
abstract class MemorySurfacingSession {
  MemorySurfacingSession._();

  static MemorySurfacingMode selected = MemorySurfacingMode.normal;
  static var lastSaveWasSensitive = false;
  static var lastSaveWasDoNotSurface = false;
  static var pickerSeenThisSession = false;

  static void notePickerSeen({required int entryCount}) {
    if (pickerSeenThisSession) return;
    pickerSeenThisSession = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memorySurfacingPickerSeen,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
    );
  }

  static void select(MemorySurfacingMode mode, {required int entryCount}) {
    selected = mode;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memorySurfacingSelected,
      entryCount: entryCount,
      surfacingMode: mode.id,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
    );
  }

  static JournalEntry applyToNewEntry(
    JournalEntry entry, {
    required int entryCount,
  }) {
    final mode = selected;
    selected = MemorySurfacingMode.normal;
    lastSaveWasSensitive = mode == MemorySurfacingMode.sensitive;
    lastSaveWasDoNotSurface = mode == MemorySurfacingMode.doNotSurface;
    final result = _copy(entry, memorySurfacing: mode.id);
    if (mode == MemorySurfacingMode.sensitive) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.entrySavedSensitive,
        entryCount: entryCount,
        surfacingMode: mode.id,
        memoryScope: MemoryScopePolicy.scope.id,
        source: 'record',
      );
    } else if (mode == MemorySurfacingMode.doNotSurface) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.entrySavedDoNotSurface,
        entryCount: entryCount,
        surfacingMode: mode.id,
        memoryScope: MemoryScopePolicy.scope.id,
        source: 'record',
      );
    }
    return result;
  }

  static JournalEntry _copy(
    JournalEntry entry, {
    required String memorySurfacing,
  }) => JournalEntry(
    id: entry.id,
    createdAt: entry.createdAt,
    transcript: entry.transcript,
    durationSeconds: entry.durationSeconds,
    reflection: entry.reflection,
    syncStatus: entry.syncStatus,
    localAudioPath: entry.localAudioPath,
    localAudioVaultRef: entry.localAudioVaultRef,
    treatAsNew: entry.treatAsNew,
    connectionApproved: entry.connectionApproved,
    keepExactDetails: entry.keepExactDetails,
    keepSeparate: entry.keepSeparate,
    archiveThreadId: entry.archiveThreadId,
    archivePackId: entry.archivePackId,
    isPinned: entry.isPinned,
    pinnedAt: entry.pinnedAt,
    isArchived: entry.isArchived,
    archivedAt: entry.archivedAt,
    entryAboutness: entry.entryAboutness,
    memorySurfacing: memorySurfacing,
    preserveOriginal: entry.preserveOriginal,
    captureContextTag: entry.captureContextTag,
  );

  static void resetAfterSave() {
    selected = MemorySurfacingMode.normal;
  }

  static void clearSaveReceipts() {
    lastSaveWasSensitive = false;
    lastSaveWasDoNotSurface = false;
  }

  static void resetSession() {
    selected = MemorySurfacingMode.normal;
    lastSaveWasSensitive = false;
    lastSaveWasDoNotSurface = false;
    pickerSeenThisSession = false;
  }

  @visibleForTesting
  static void resetSessionForTest() => resetSession();
}

abstract class MemorySurfacingCopy {
  MemorySurfacingCopy._();

  static const String sectionTitle = 'Surfacing';
  static const String surfacingTitle = 'Surfacing';
  static const String normalLabel = 'Normal';
  static const String sensitiveLabel = 'Sensitive';
  static const String doNotSurfaceLabel = 'Do not surface';
  static const String normalHelper =
      'ArchiveMe can use this in archive moments when allowed.';
  static const String sensitiveHelper =
      'Keep this saved, but treat it carefully.';
  static const String doNotSurfaceHelper =
      'Keep this searchable, but do not bring it back unless you ask.';
  static const String sensitiveReceipt = 'Saved with cautious resurfacing.';
  static const String doNotSurfaceReceipt =
      'Saved without proactive resurfacing.';
  static const String updatedTitle = 'Surfacing updated';
  static const String updatedHelper =
      'ArchiveMe will respect this choice going forward.';
  static const String changeSurfacingLabel = 'Change surfacing';
  static const String searchFilterLabel = 'Surfacing';

  static const List<String> all = [
    sectionTitle,
    surfacingTitle,
    normalLabel,
    sensitiveLabel,
    doNotSurfaceLabel,
    normalHelper,
    sensitiveHelper,
    doNotSurfaceHelper,
    sensitiveReceipt,
    doNotSurfaceReceipt,
    updatedTitle,
    updatedHelper,
    changeSurfacingLabel,
    searchFilterLabel,
  ];
}
