import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';

/// Memory and evidence safeguards for user-created facts.
///
/// Facts are discrete records for exact recall — not personality profile
/// evidence and not inputs to proactive personal memory engines.
abstract class FactLedgerPolicy {
  FactLedgerPolicy._();

  /// Facts are never personality/profile evidence.
  static bool isPersonalProfileEvidence(ArchiveFact fact) => false;

  /// Facts do not feed belief distance, aha moments, weekly personal review,
  /// or Pro proof surfaces by themselves.
  static bool feedsProactivePersonalMemory(ArchiveFact fact) => false;

  /// Facts may support pack/project recall when the user opens pack detail,
  /// search, or the Details screen.
  static bool supportsPackRecall(ArchiveFact fact) =>
      fact.archivePackId != null && fact.archivePackId!.isNotEmpty;

  /// Facts stay within their pack unless the user explicitly saves elsewhere.
  static bool crossesPackWithoutConfirmation({
    required ArchiveFact fact,
    String? targetPackId,
  }) =>
      fact.archivePackId != null &&
      targetPackId != null &&
      fact.archivePackId != targetPackId;

  /// User-created only — no automatic extraction path exists in the store.
  static bool isUserCreatedOnly(ArchiveFact fact) => fact.id.isNotEmpty;
}