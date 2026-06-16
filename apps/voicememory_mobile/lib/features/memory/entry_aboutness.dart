import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// Whether an entry is personal evidence or saved for another purpose.
enum EntryAboutness {
  aboutMe('about_me'),
  hypothetical('hypothetical'),
  notAboutMe('not_about_me'),
  projectMaterial('project_material'),
  researchNote('research_note');

  const EntryAboutness(this.id);

  final String id;

  String get label => switch (this) {
    EntryAboutness.aboutMe => EntryAboutnessCopy.aboutMeLabel,
    EntryAboutness.hypothetical => EntryAboutnessCopy.hypotheticalLabel,
    EntryAboutness.notAboutMe => EntryAboutnessCopy.notAboutMeLabel,
    EntryAboutness.projectMaterial => EntryAboutnessCopy.projectMaterialLabel,
    EntryAboutness.researchNote => EntryAboutnessCopy.researchNoteLabel,
  };

  String get helper => switch (this) {
    EntryAboutness.aboutMe => EntryAboutnessCopy.aboutMeHelper,
    EntryAboutness.hypothetical => EntryAboutnessCopy.hypotheticalHelper,
    EntryAboutness.notAboutMe => EntryAboutnessCopy.notAboutMeHelper,
    EntryAboutness.projectMaterial => EntryAboutnessCopy.projectMaterialHelper,
    EntryAboutness.researchNote => EntryAboutnessCopy.researchNoteHelper,
  };

  bool get isPersonalEvidence => this == EntryAboutness.aboutMe;

  bool get showsNonPersonalReceipt =>
      this == EntryAboutness.hypothetical || this == EntryAboutness.notAboutMe;

  static EntryAboutness fromId(String? id) {
    if (id == null || id.isEmpty) return EntryAboutness.aboutMe;
    for (final value in values) {
      if (value.id == id) return value;
    }
    return EntryAboutness.aboutMe;
  }

  static EntryAboutness fromEntry(JournalEntry entry) =>
      fromId(entry.entryAboutness);
}

/// Session selection for the next save.
abstract class EntryAboutnessSession {
  EntryAboutnessSession._();

  static EntryAboutness selected = EntryAboutness.aboutMe;
  static var lastSaveWasNonPersonal = false;
  static var pickerSeenThisSession = false;

  static void notePickerSeen({required int entryCount}) {
    if (pickerSeenThisSession) return;
    pickerSeenThisSession = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryAboutnessPickerSeen,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
    );
  }

  static void select(EntryAboutness aboutness, {required int entryCount}) {
    selected = aboutness;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryAboutnessSelected,
      entryCount: entryCount,
      entryAboutness: aboutness.id,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
    );
  }

  static JournalEntry applyToNewEntry(
    JournalEntry entry, {
    required int entryCount,
  }) {
    final aboutness = selected;
    selected = EntryAboutness.aboutMe;
    lastSaveWasNonPersonal = aboutness.showsNonPersonalReceipt;
    final result = _copy(entry, aboutness: aboutness.id);
    if (!aboutness.isPersonalEvidence) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.entrySavedNonPersonal,
        entryCount: entryCount,
        entryAboutness: aboutness.id,
        memoryScope: MemoryScopePolicy.scope.id,
        source: 'record',
      );
    }
    return result;
  }

  static JournalEntry _copy(JournalEntry entry, {required String aboutness}) =>
      JournalEntry(
        id: entry.id,
        createdAt: entry.createdAt,
        transcript: entry.transcript,
        durationSeconds: entry.durationSeconds,
        reflection: entry.reflection,
        syncStatus: entry.syncStatus,
        localAudioPath: entry.localAudioPath,
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
        entryAboutness: aboutness,
        memorySurfacing: entry.memorySurfacing,
      );

  static void resetAfterSave() {
    selected = EntryAboutness.aboutMe;
  }

  static void clearSaveReceipt() {
    lastSaveWasNonPersonal = false;
  }

  @visibleForTesting
  static void resetSessionForTest() {
    selected = EntryAboutness.aboutMe;
    lastSaveWasNonPersonal = false;
    pickerSeenThisSession = false;
  }
}

abstract class EntryAboutnessCopy {
  EntryAboutnessCopy._();

  static const String sectionTitle = 'What kind of entry is this?';
  static const String entryTypeTitle = 'Entry type';
  static const String aboutMeLabel = 'About me';
  static const String hypotheticalLabel = 'Hypothetical';
  static const String notAboutMeLabel = 'Not about me';
  static const String projectMaterialLabel = 'Project material';
  static const String researchNoteLabel = 'Research note';
  static const String aboutMeHelper =
      'This can help your archive notice what returns or changes.';
  static const String hypotheticalHelper =
      'Save this as an idea, not personal evidence.';
  static const String notAboutMeHelper =
      'Save this without using it to shape personal patterns.';
  static const String projectMaterialHelper =
      'Keep this with your archive, but separate from personal patterns.';
  static const String researchNoteHelper =
      'Save this as something you are exploring.';
  static const String nonPersonalReceipt =
      'Saved without shaping personal patterns.';

  static const List<String> all = [
    sectionTitle,
    entryTypeTitle,
    aboutMeLabel,
    hypotheticalLabel,
    notAboutMeLabel,
    projectMaterialLabel,
    researchNoteLabel,
    aboutMeHelper,
    hypotheticalHelper,
    notAboutMeHelper,
    projectMaterialHelper,
    researchNoteHelper,
    nonPersonalReceipt,
  ];
}
