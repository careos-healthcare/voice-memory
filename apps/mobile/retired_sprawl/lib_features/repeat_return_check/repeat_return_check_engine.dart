import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_gates.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Resolves when to show repeat return check surfaces.
abstract final class RepeatReturnCheckEngine {
  RepeatReturnCheckEngine._();

  static RepeatReturnCheckOffer? pendingForSave({
    required List<JournalEntry> entriesAfterSave,
    List<RepeatReturnCheckRecord>? records,
  }) {
    if (entriesAfterSave.isEmpty) return null;

    final entryId = RepeatReturnCheckStore.latestSavedEntryId(entriesAfterSave);
    final existing = records
        ?.where((record) => record.entryId == entryId)
        .firstOrNull;
    if (!RepeatReturnCheckGates.shouldOfferForEntry(
      entriesAfterSave: entriesAfterSave,
      existing: existing,
    )) {
      return null;
    }

    return RepeatReturnCheckOffer(
      entryId: entryId,
      entryCount: entriesAfterSave.length,
    );
  }

  static RepeatReturnCheckChangeProof? changeProofForReady({
    required int entryCount,
    required bool viewingConfirmedRepeat,
    required bool isRecording,
    required bool isPostSave,
    List<RepeatReturnCheckRecord>? records,
  }) {
    final resolved = records ?? RepeatReturnCheckStore.cached;
    if (!RepeatReturnCheckGates.shouldShowChangeProofCard(
      entryCount: entryCount,
      viewingConfirmedRepeat: viewingConfirmedRepeat,
      isRecording: isRecording,
      isPostSave: isPostSave,
      records: resolved,
    )) {
      return null;
    }

    final body = RepeatReturnCheckTrendEngine.changeProofBody(resolved);
    final latestChoice = RepeatReturnCheckTrendEngine.latestChoice(resolved);
    if (body == null || latestChoice == null) return null;

    return RepeatReturnCheckChangeProof(
      title: RepeatReturnCheckCopy.changeProofTitle,
      body: body,
      latestChoice: latestChoice,
    );
  }

  /// Future-facing summary from stored metadata only.
  static String? trendCopy({List<RepeatReturnCheckRecord>? records}) =>
      RepeatReturnCheckTrendEngine.changeProofBody(
        records ?? RepeatReturnCheckStore.cached,
      );
}

class RepeatReturnCheckOffer {
  const RepeatReturnCheckOffer({
    required this.entryId,
    required this.entryCount,
  });

  final String entryId;
  final int entryCount;
}