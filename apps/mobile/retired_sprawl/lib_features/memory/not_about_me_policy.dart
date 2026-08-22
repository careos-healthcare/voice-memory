import 'package:archiveme_mobile/features/memory/entry_aboutness.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';

/// Policy for non-personal entries — saved and searchable, not personal evidence.
abstract class NotAboutMePolicy {
  NotAboutMePolicy._();

  static const Set<MemoryCardType> personalMemoryCards = {
    MemoryCardType.threadReturn,
    MemoryCardType.beliefDistance,
    MemoryCardType.weeklyReview,
  };

  static bool isPersonalEvidence(EntryAboutness aboutness) =>
      aboutness.isPersonalEvidence;

  static bool isPersonalEvidenceId(String? id) =>
      isPersonalEvidence(EntryAboutness.fromId(id));

  static bool isPersonalEvidenceRecord(PressureCheckInRecord record) =>
      isPersonalEvidenceId(record.entryAboutness);

  static bool isPersonalEvidenceEntry(JournalEntry entry) =>
      isPersonalEvidenceId(entry.entryAboutness);

  static bool blocksPersonalMemoryClaims(EntryAboutness aboutness) =>
      !isPersonalEvidence(aboutness);

  static bool blocksPersonalMemoryClaimsId(String? id) =>
      blocksPersonalMemoryClaims(EntryAboutness.fromId(id));

  static List<PressureCheckInRecord> personalEvidenceOnly(
    List<PressureCheckInRecord> records,
  ) => records.where(isPersonalEvidenceRecord).toList();

  static bool isPersonalMemoryCard(MemoryCardType cardType) =>
      personalMemoryCards.contains(cardType);

  static void trackBlocked({required String source, int? entryCount}) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.nonPersonalMemoryBlocked,
      source: source,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static bool excludesFromProTrustReceipt(JournalEntry entry) =>
      blocksPersonalMemoryClaimsId(entry.entryAboutness) ||
      MemoryScopePolicy.scope == MemoryScope.off;
}