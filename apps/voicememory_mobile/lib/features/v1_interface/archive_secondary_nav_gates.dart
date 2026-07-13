import 'progressive_evidence_state_copy.dart';

/// Gates for Discover / Timeline / Search as Archive secondary links — not top-level tabs.
abstract final class ArchiveSecondaryNavGates {
  ArchiveSecondaryNavGates._();

  static const minUsefulEntriesForSecondaryLinks =
      ProgressiveEvidenceStateCopy.archiveOpensAt;

  static const minEntriesForRicherDiscover =
      ProgressiveEvidenceStateCopy.richerDiscoverAt;

  static bool showSecondaryLinks({required int entryCount}) =>
      entryCount >= minUsefulEntriesForSecondaryLinks;

  static bool showRicherDiscoverSections({required int entryCount}) =>
      entryCount >= minEntriesForRicherDiscover;
}
