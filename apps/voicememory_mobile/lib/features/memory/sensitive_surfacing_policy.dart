import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'memory_control_model.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';
import 'memory_surfacing_mode.dart';

/// Where archive content may appear — stable ids only.
enum MemorySurfaceType {
  search('search'),
  directOpen('direct_open'),
  selectedExport('selected_export'),
  packDetail('pack_detail'),
  pinnedScreen('pinned_screen'),
  actionItems('action_items'),
  evidenceInspection('evidence_inspection'),
  recordContext('record_context'),
  ahaMoment('aha_moment'),
  threadReturn('thread_return'),
  weeklyReview('weekly_review'),
  beliefDistance('belief_distance'),
  proProof('pro_proof'),
  shareCard('share_card');

  const MemorySurfaceType(this.id);

  final String id;

  bool get isUserInitiated => switch (this) {
    MemorySurfaceType.search ||
    MemorySurfaceType.directOpen ||
    MemorySurfaceType.selectedExport ||
    MemorySurfaceType.packDetail ||
    MemorySurfaceType.pinnedScreen ||
    MemorySurfaceType.actionItems ||
    MemorySurfaceType.evidenceInspection => true,
    _ => false,
  };

  bool get isProactive => !isUserInitiated;

  static MemorySurfaceType fromCardType(MemoryCardType cardType) =>
      switch (cardType) {
        MemoryCardType.threadReturn => MemorySurfaceType.threadReturn,
        MemoryCardType.beliefDistance => MemorySurfaceType.beliefDistance,
        MemoryCardType.weeklyReview => MemorySurfaceType.weeklyReview,
      };

  static MemorySurfaceType? fromSource(String? source) {
    switch (source) {
      case 'search':
      case 'archive_search':
        return MemorySurfaceType.search;
      case 'entry_detail':
      case 'journal':
        return MemorySurfaceType.directOpen;
      case 'export':
      case 'bulk_export':
        return MemorySurfaceType.selectedExport;
      case 'pack_detail':
        return MemorySurfaceType.packDetail;
      case 'pinned':
      case 'pinned_evidence':
        return MemorySurfaceType.pinnedScreen;
      case 'action_items':
        return MemorySurfaceType.actionItems;
      case 'evidence_inspection':
      case 'memory_evidence':
        return MemorySurfaceType.evidenceInspection;
      case 'record':
        return MemorySurfaceType.recordContext;
      case 'aha_engine':
      case 'archive':
        return MemorySurfaceType.ahaMoment;
      case 'pro_proof':
      case 'pro_trust':
        return MemorySurfaceType.proProof;
      case 'share':
        return MemorySurfaceType.shareCard;
      default:
        return null;
    }
  }
}

/// Policy outcome — narrows or blocks, never widens governance.
enum SensitiveSurfacingOutcome {
  allowed,
  blocked,
  backgroundOnly,
  cautious,
  userInitiatedOnly,
}

/// Central surfacing guard — user choice only, never content inference.
abstract class SensitiveSurfacingPolicy {
  SensitiveSurfacingPolicy._();

  static const Set<MemorySurfaceType> highIntensityProactive = {
    MemorySurfaceType.ahaMoment,
    MemorySurfaceType.threadReturn,
    MemorySurfaceType.weeklyReview,
    MemorySurfaceType.beliefDistance,
    MemorySurfaceType.proProof,
    MemorySurfaceType.shareCard,
  };

  static MemorySurfacingMode modeForRecord(PressureCheckInRecord record) =>
      MemorySurfacingMode.fromId(record.memorySurfacing);

  static MemorySurfacingMode modeForEntry(JournalEntry entry) =>
      MemorySurfacingMode.fromEntry(entry);

  static bool isDoNotSurfaceRecord(PressureCheckInRecord record) =>
      modeForRecord(record).blocksProactiveResurfacing;

  static bool isDoNotSurfaceEntry(JournalEntry entry) =>
      modeForEntry(entry).blocksProactiveResurfacing;

  static bool isSensitiveRecord(PressureCheckInRecord record) =>
      modeForRecord(record) == MemorySurfacingMode.sensitive;

  static bool isSensitiveEntry(JournalEntry entry) =>
      modeForEntry(entry) == MemorySurfacingMode.sensitive;

  static List<PressureCheckInRecord> proactiveClaimEligible(
    List<PressureCheckInRecord> records,
  ) =>
      records.where((r) => !modeForRecord(r).limitsProactiveIntensity).toList();

  static List<PressureCheckInRecord> automaticContextEligible(
    List<PressureCheckInRecord> records,
  ) => records
      .where((r) => modeForRecord(r) == MemorySurfacingMode.normal)
      .toList();

  static SensitiveSurfacingOutcome evaluate({
    required MemorySurfacingMode mode,
    required MemorySurfaceType surfaceType,
    bool userInitiated = false,
  }) {
    if (MemoryScopePolicy.scope == MemoryScope.off && surfaceType.isProactive) {
      return SensitiveSurfacingOutcome.blocked;
    }

    if (mode == MemorySurfacingMode.doNotSurface) {
      if (userInitiated || surfaceType.isUserInitiated) {
        return SensitiveSurfacingOutcome.userInitiatedOnly;
      }
      return SensitiveSurfacingOutcome.blocked;
    }

    if (mode == MemorySurfacingMode.sensitive) {
      if (surfaceType == MemorySurfaceType.evidenceInspection &&
          userInitiated) {
        return SensitiveSurfacingOutcome.cautious;
      }
      if (surfaceType == MemorySurfaceType.recordContext) {
        return SensitiveSurfacingOutcome.cautious;
      }
      if (highIntensityProactive.contains(surfaceType)) {
        return SensitiveSurfacingOutcome.blocked;
      }
      if (surfaceType.isUserInitiated) {
        return SensitiveSurfacingOutcome.userInitiatedOnly;
      }
      return SensitiveSurfacingOutcome.backgroundOnly;
    }

    return SensitiveSurfacingOutcome.allowed;
  }

  static bool allowsProactiveMemoryClaim({
    required MemorySurfacingMode mode,
    required MemoryCardType cardType,
  }) {
    final surface = MemorySurfaceType.fromCardType(cardType);
    final outcome = evaluate(mode: mode, surfaceType: surface);
    return outcome == SensitiveSurfacingOutcome.allowed ||
        outcome == SensitiveSurfacingOutcome.backgroundOnly;
  }

  static bool blocksProactiveCardForRecords(
    List<PressureCheckInRecord> records,
  ) {
    final eligible = proactiveClaimEligible(records);
    return records.isNotEmpty && eligible.isEmpty;
  }

  static bool excludesFromProTrustReceipt(JournalEntry entry) =>
      modeForEntry(entry).limitsProactiveIntensity ||
      MemoryScopePolicy.scope == MemoryScope.off;

  static void trackBlocked({
    required MemorySurfaceType surfaceType,
    required MemorySurfacingMode mode,
    String source = 'memory_card',
    int? entryCount,
  }) {
    final event = mode == MemorySurfacingMode.doNotSurface
        ? ActivationFunnelAnalytics.doNotSurfaceBlocked
        : ActivationFunnelAnalytics.sensitiveSurfacingBlocked;
    ActivationFunnelAnalytics.track(
      event,
      surfacingMode: mode.id,
      surfaceType: surfaceType.id,
      source: source,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void trackUserOpened({
    required MemorySurfacingMode mode,
    required MemorySurfaceType surfaceType,
    String source = 'entry_detail',
  }) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.sensitiveSurfacingUserOpened,
      surfacingMode: mode.id,
      surfaceType: surfaceType.id,
      source: source,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }
}
