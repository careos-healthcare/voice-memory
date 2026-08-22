import 'package:archiveme_mobile/features/v1_interface/progressive_evidence_state_copy.dart';

/// Gates for Discover / Timeline / Search as Archive secondary links — not top-level tabs.
abstract final class ArchiveSecondaryNavGates {
  ArchiveSecondaryNavGates._();

  static const int minUsefulEntriesForSecondaryLinks =
      ProgressiveEvidenceStateCopy.archiveOpensAt;

  static const int minEntriesForRicherDiscover =
      ProgressiveEvidenceStateCopy.richerDiscoverAt;

  static bool showSecondaryLinks({required int entryCount}) =>
      entryCount >= minUsefulEntriesForSecondaryLinks;

  static bool showRicherDiscoverSections({required int entryCount}) =>
      entryCount >= minEntriesForRicherDiscover;
}