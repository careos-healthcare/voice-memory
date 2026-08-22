import 'package:archiveme_mobile/features/revenue_foundation/revenue_value_copy.dart';
import 'package:archiveme_mobile/features/revenue_foundation/revenue_value_model.dart';

/// Safe revenue value flags and copy — no billing, sync, or journal access.
abstract final class RevenueValueEngine {
  RevenueValueEngine._();

  /// Partial: export/recap exists in product map; enforcement varies by surface.
  static bool exportReportsLive = true;

  /// Partial: private report preview and recap surfaces exist.
  static bool privateReportsLive = true;

  /// Live (positioning): longer history is the core Pro story.
  static bool longTermHistoryLive = true;

  /// Always false for consumer promises — sharing is future-only in v1 foundation.
  static bool safeSharingLive = false;

  static RevenueValueFoundation build() {
    final exportLive = exportReportsLive;
    final privateLive = privateReportsLive;
    final historyLive = longTermHistoryLive;
    const sharingLive = false;

    return RevenueValueFoundation(
      hasClearPaidReason: true,
      longTermHistoryValue: historyLive,
      privateReportValue: privateLive,
      exportValue: exportLive,
      safeSharingFutureValue: !sharingLive,
      exportReportsLive: exportLive,
      privateReportsLive: privateLive,
      longTermHistoryLive: historyLive,
      safeSharingLive: sharingLive,
      paidReasonHeadline: RevenueValueCopy.paidReasonHeadline,
      paidReasonBody: RevenueValueCopy.paidReasonBody,
      paidReasonEvidenceLine: RevenueValueCopy.paidReasonEvidenceLine,
      chatGptDifferentiationLine: RevenueValueCopy.chatGptDifferentiationLine,
      comparesMomentsLine: RevenueValueCopy.comparesMomentsLine,
      longTermHistoryHeadline: RevenueValueCopy.longTermHistoryHeadline,
      longTermHistoryBody: RevenueValueCopy.longTermHistoryBody,
      privateReportHeadline: RevenueValueCopy.privateReportHeadline,
      privateReportBody: RevenueValueCopy.privateReportBody,
      exportHeadline: RevenueValueCopy.exportHeadline,
      exportBody: RevenueValueCopy.exportBodyForDisplay(
        exportReportsLive: exportLive,
      ),
      exportLabel: RevenueValueCopy.exportLabelForDisplay(
        exportReportsLive: exportLive,
      ),
      safeSharingHeadline: RevenueValueCopy.safeSharingHeadline,
      safeSharingBody: RevenueValueCopy.safeSharingBody,
      safeSharingDisclaimer: RevenueValueCopy.safeSharingDisclaimer,
      safeSharingChoice: RevenueValueCopy.safeSharingChoice,
      safeSharingFutureNote: RevenueValueCopy.safeSharingFutureNote,
      positioningHeadline: RevenueValueCopy.positioningHeadline,
      positioningSubhead: RevenueValueCopy.positioningSubhead,
      memoryJob: RevenueValueCopy.memoryJob,
    );
  }

  static bool mentionsPaidMemoryNotAi(RevenueValueFoundation foundation) {
    final blob = [
      foundation.paidReasonBody,
      foundation.paidReasonEvidenceLine,
      foundation.longTermHistoryBody,
      foundation.privateReportBody,
    ].join(' ').toLowerCase();
    if (blob.contains('more ai')) return false;
    if (blob.contains('smarter chat')) return false;
    if (blob.contains('unlimited chat')) return false;
    return blob.contains('history') ||
        blob.contains('report') ||
        blob.contains('evidence') ||
        blob.contains('archive');
  }

  static bool differentiatesFromChat(RevenueValueFoundation foundation) {
    final blob = foundation.allVisibleStrings.join(' ').toLowerCase();
    return blob.contains('chatgpt') &&
        blob.contains('not a chat') &&
        (blob.contains('shows what you already said') ||
            blob.contains('not a chatbot'));
  }

  static bool hasNoMedicalClaims(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    for (final term in RevenueValueCopy.bannedMedicalTerms) {
      if (blob.contains(term)) return false;
    }
    return true;
  }

  static bool futureFeaturesNotPresentedAsLive(
    RevenueValueFoundation foundation,
  ) {
    if (foundation.safeSharingLive) return false;
    final blob = foundation.allVisibleStrings.join(' ').toLowerCase();
    for (final term in RevenueValueCopy.bannedLiveOverpromises) {
      if (blob.contains(term)) return false;
    }
    if (!foundation.exportReportsLive &&
        foundation.exportBody.toLowerCase().contains('planned')) {
      return true;
    }
    if (foundation.exportReportsLive) {
      return !blob.contains('not available in the app yet') ||
          foundation.safeSharingFutureNote.toLowerCase().contains('future');
    }
    return foundation.safeSharingFutureNote.toLowerCase().contains('future');
  }
}