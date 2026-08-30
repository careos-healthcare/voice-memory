import 'dart:async';

import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sensitive_prefs_encrypted_blob.dart';
import 'package:flutter/foundation.dart';

/// Which archive insight surface the user is responding to.
enum ArchiveInsightTarget {
  archiveHome,
  weeklyReview,
  beliefEvidence,
  beliefUpdate,
}

/// Local feedback choice — never synced to a backend.
enum ArchiveInsightFeedbackChoice { feelsRight, notQuite }

/// User-facing copy for insight feedback controls.
abstract final class ArchiveInsightFeedbackCopy {
  static const String feelsRight = VisibleArchiveProofCopy.insightFeedbackFeelsRight;

  static const String notQuite = VisibleArchiveProofCopy.insightFeedbackNotQuite;

  static const String hideThis = VisibleArchiveProofCopy.insightFeedbackHideThis;

  static const String whySeeing = VisibleArchiveProofCopy.insightFeedbackWhySeeing;

  static const String whySource = VisibleArchiveProofCopy.insightFeedbackWhySource;

  static const String whyNotConclusion =
      VisibleArchiveProofCopy.insightFeedbackWhyNotConclusion;

  static const String whyHide = VisibleArchiveProofCopy.insightFeedbackWhyHide;

  static const String correctionAffordance =
      VisibleArchiveProofCopy.insightCorrectionAffordance;

  static const String correctionPlaceholder =
      VisibleArchiveProofCopy.insightCorrectionPlaceholder;

  static const String correctionSaveCta =
      VisibleArchiveProofCopy.insightCorrectionSaveCta;

  static const String correctionSkipCta =
      VisibleArchiveProofCopy.insightCorrectionSkipCta;

  static const String correctionMarkedNotQuite =
      VisibleArchiveProofCopy.insightCorrectionMarkedNotQuite;

  static const String correctionYourNotePrefix =
      VisibleArchiveProofCopy.insightCorrectionYourNotePrefix;
}

/// Visibility gates — no controls on premature early-ladder surfaces.
abstract final class ArchiveInsightFeedbackGate {
  ArchiveInsightFeedbackGate._();

  static bool showForArchiveHome(ArchiveHomeStage stage) =>
      stage == ArchiveHomeStage.three ||
      stage == ArchiveHomeStage.four ||
      stage == ArchiveHomeStage.fivePlus;

  static bool showForWeeklyReview({required bool hasEnoughEvidence}) =>
      hasEnoughEvidence;

  static bool showForBeliefEvidence({required bool hasEnoughEvidence}) =>
      hasEnoughEvidence;

  static bool showForBeliefUpdate() => true;
}

/// Local-only store for insight feedback and hide state.
abstract final class ArchiveInsightFeedbackStore {
  ArchiveInsightFeedbackStore._();

  static const _prefsKey = 'archive_insight_feedback';
  static const _secureCorrectionNotesKey =
      'secure_archive_insight_correction_notes_v1';
  static const _legacyCorrectionNotesField = 'correctionNotes';

  static const maxCorrectionNoteLength = 240;

  static final Set<String> _hidden = <String>{};
  static final Map<String, int> _feelsRight = <String, int>{};
  static final Map<String, int> _notQuite = <String, int>{};
  static final Map<String, String> _correctionNotes = <String, String>{};

  static bool _loaded = false;
  static bool _migrationComplete = false;
  static Future<void> _persistChain = Future<void>.value();

  static String archiveHomeId(ArchiveHomeStage stage) =>
      'archive_home_${stage.name}';

  static String targetId(ArchiveInsightTarget target) => target.name;

  static bool isHidden(String insightId) => _hidden.contains(insightId);

  static int feelsRightCount(String insightId) => _feelsRight[insightId] ?? 0;

  static int notQuiteCount(String insightId) => _notQuite[insightId] ?? 0;

  static String? correctionNote(String insightId) =>
      _correctionNotes[insightId];

  static bool hasCorrectionNote(String insightId) =>
      _correctionNotes[insightId]?.trim().isNotEmpty ?? false;

  static String? normalizeCorrectionNote(String rawNote) {
    final trimmed = rawNote.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxCorrectionNoteLength) return trimmed;
    return trimmed.substring(0, maxCorrectionNoteLength);
  }

  static Future<bool> saveCorrectionNote(String insightId, String rawNote) async {
    final normalized = normalizeCorrectionNote(rawNote);
    if (normalized == null) return false;
    _correctionNotes[insightId] = normalized;
    await _persistAll();
    return true;
  }

  static Future<void> record(
    String insightId,
    ArchiveInsightFeedbackChoice choice,
  ) async {
    switch (choice) {
      case ArchiveInsightFeedbackChoice.feelsRight:
        _feelsRight[insightId] = feelsRightCount(insightId) + 1;
      case ArchiveInsightFeedbackChoice.notQuite:
        _notQuite[insightId] = notQuiteCount(insightId) + 1;
    }
    await _persistAll();
  }

  static Future<void> hide(String insightId) async {
    _hidden.add(insightId);
    await _persistAll();
  }

  static Future<void> unhide(String insightId) async {
    _hidden.remove(insightId);
    await _persistAll();
  }

  static Future<void> clearFeedback(String insightId) async {
    _feelsRight.remove(insightId);
    _notQuite.remove(insightId);
    await _persistAll();
  }

  static Future<void> deleteCorrectionNote(String insightId) async {
    _correctionNotes.remove(insightId);
    await _persistAll();
  }

  static int totalFeelsRightCount() =>
      _feelsRight.values.fold<int>(0, (sum, count) => sum + count);

  static int totalNotQuiteCount() =>
      _notQuite.values.fold<int>(0, (sum, count) => sum + count);

  static int hiddenInsightCount() => _hidden.length;

  static int correctionNoteCount() => _correctionNotes.length;

  static bool hasAnyFeedback() =>
      totalFeelsRightCount() > 0 ||
      totalNotQuiteCount() > 0 ||
      hiddenInsightCount() > 0 ||
      correctionNoteCount() > 0;

  static List<String> allKnownInsightIds() {
    final ids = <String>{
      ..._hidden,
      ..._feelsRight.keys,
      ..._notQuite.keys,
      ..._correctionNotes.keys,
    };
    return ids.toList()..sort();
  }

  static List<String> notQuiteInsightIds() {
    return _notQuite.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  static List<String> hiddenInsightIds() => _hidden.toList()..sort();

  static List<String> correctionNoteInsightIds() =>
      _correctionNotes.keys.toList()..sort();

  static List<Map<String, String>> exportCorrectionNotes() {
    final rows = <Map<String, String>>[];
    for (final insightId in correctionNoteInsightIds()) {
      final note = correctionNote(insightId);
      if (note == null || note.isEmpty) continue;
      rows.add({
        'insightId': insightId,
        'label': friendlyExportLabel(insightId),
        'note': note,
      });
    }
    return rows;
  }

  static String friendlyExportLabel(String insightId) {
    if (insightId.startsWith('archive_home_')) {
      return 'Archive home insight correction';
    }
    return switch (insightId) {
      'weeklyReview' => 'Weekly review insight correction',
      'beliefEvidence' => 'Belief evidence insight correction',
      'beliefUpdate' => 'Belief update insight correction',
      _ => 'Insight correction',
    };
  }

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    await _runMigrationIfNeeded();
    await _loadMetadata();
    _correctionNotes
      ..clear()
      ..addAll(await _correctionNotesBlob().readStringMap());
    _loaded = true;
  }

  static Future<void> _runMigrationIfNeeded() async {
    if (_migrationComplete || !AppServices.isInitialized) return;
    await _correctionNotesBlob().migrateLegacyStringMapField(
      legacyPrefsKey: _prefsKey,
      legacyFieldName: _legacyCorrectionNotesField,
    );
    _migrationComplete = true;
  }

  static Future<void> _loadMetadata() async {
    final raw = await AppServices.instance.prefs.readMap(_prefsKey);
    if (raw == null) return;
    _hidden
      ..clear()
      ..addAll((raw['hidden'] as List<dynamic>? ?? []).whereType<String>());
    _feelsRight.clear();
    final feelsRightRaw = raw['feelsRight'];
    if (feelsRightRaw is Map) {
      for (final entry in feelsRightRaw.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key != null && value is num) {
          _feelsRight[key] = value.toInt();
        }
      }
    }
    _notQuite.clear();
    final notQuiteRaw = raw['notQuite'];
    if (notQuiteRaw is Map) {
      for (final entry in notQuiteRaw.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key != null && value is num) {
          _notQuite[key] = value.toInt();
        }
      }
    }
  }

  static Future<void> _persistAll() async {
    if (!AppServices.isInitialized) return;
    final completer = Completer<void>();
    final previous = _persistChain;
    _persistChain = completer.future;
    await previous;
    try {
      await _persistMetadata();
      await _correctionNotesBlob().writeStringMap(
        Map<String, String>.from(_correctionNotes),
      );
    } finally {
      completer.complete();
    }
  }

  static Future<void> _persistMetadata() async {
    await AppServices.instance.prefs.writeMap(_prefsKey, {
      'hidden': _hidden.toList()..sort(),
      'feelsRight': _feelsRight,
      'notQuite': _notQuite,
    });
  }

  static SensitivePrefsEncryptedBlob _correctionNotesBlob() {
    return SensitivePrefsEncryptedBlob(
      prefs: AppServices.instance.prefs,
      encryptedStorage: AppServices.instance.personalContentEncryptedStorage,
      securePrefsKey: _secureCorrectionNotesKey,
      payloadRootKey: 'notes',
    );
  }

  static Future<void> clearAll() async {
    _hidden.clear();
    _feelsRight.clear();
    _notQuite.clear();
    _correctionNotes.clear();
    _loaded = true;
    _migrationComplete = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(_prefsKey, {});
    await _correctionNotesBlob().clear();
  }

  @visibleForTesting
  static Future<void> flushForTest() => _persistChain;

  @visibleForTesting
  static Future<void> resetForTest() async {
    await flushForTest();
    _hidden.clear();
    _feelsRight.clear();
    _notQuite.clear();
    _correctionNotes.clear();
    _loaded = false;
    _migrationComplete = false;
    _persistChain = Future<void>.value();
  }

  @visibleForTesting
  static MobilePrefsStore? prefsForTest() =>
      AppServices.isInitialized ? AppServices.instance.prefs : null;
}
