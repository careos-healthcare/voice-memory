import '../early_archive/early_first_signal_engine.dart';
import 'paywall_timing_gates.dart';

/// Visibility gates for the first-three-session product loop.
abstract class FirstThreeSessionGates {
  FirstThreeSessionGates._();

  static const int minEntriesForRepeatSurface = 2;
  static const int minEntriesForUsefulArchive = 3;

  /// First-three loop owns Record at counts 1–3 — hide competing map prompts.
  static bool suppressDailyMapPromptOnRecord(int entryCount) =>
      entryCount >= 1 && entryCount <= minEntriesForUsefulArchive;

  /// Card CTAs that duplicate the capture bar stay off at 1–2 until repeat is clearer.
  static bool showEarlyFirstSignalCardPrimaryCta(EarlyFirstSignalKind kind) {
    switch (kind) {
      case EarlyFirstSignalKind.oneEntryReceipt:
      case EarlyFirstSignalKind.twoEntryNoPattern:
        return false;
      case EarlyFirstSignalKind.twoEntryFirstSignal:
      case EarlyFirstSignalKind.threeEntryConfirmedRepeat:
        return true;
    }
  }

  /// Hide noisy post-save cards while the first-save confirmation is showing.
  static bool suppressNoisyPostSaveCards({
    required bool justSavedFirst,
    required int entryCount,
  }) => justSavedFirst && entryCount == 1;

  /// Hide "possible repeat" / hypothesis cards after the second save unless
  /// the overlap is grounded in the user's own words.
  static bool suppressEarlyPatternClaimCards({
    required int entryCount,
    required bool hasGroundedRepeatMatch,
  }) => entryCount == minEntriesForRepeatSurface && !hasGroundedRepeatMatch;

  static bool showSession2RepeatSurface(int entryCount) =>
      entryCount >= minEntriesForRepeatSurface;

  static bool showSession3ArchiveSurface(int entryCount) =>
      entryCount >= minEntriesForUsefulArchive;

  /// Pro bridge only after repeat / archive value — never on first save.
  static bool showSoftProBridge({
    required int entryCount,
    required bool resolved,
    required bool isPro,
    required bool hasArchiveProof,
  }) => PaywallTimingGates.showSoftProBridge(
    entryCount: entryCount,
    resolved: resolved,
    isPro: isPro,
    hasArchiveProof: hasArchiveProof,
  );
}
