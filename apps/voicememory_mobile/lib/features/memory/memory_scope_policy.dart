import 'package:flutter/foundation.dart';

import '../pressure_retention/pressure_check_in_record.dart';
import 'memory_scope.dart';

/// Central memory policy — the single place that decides which saved
/// records the memory/insight engines may use for connection claims.
/// Engines never invent their own scope behavior.
///
/// Rules:
/// - `off`: no records are eligible — no connection claims anywhere.
/// - Any scope: `treatAsNew` and `keepSeparate` records are ignored.
/// - `ask`: only records the user explicitly connected are eligible.
/// - `threadOnly`: only records linked by an explicit shared archive
///   thread id or shared context marker are eligible — generic
///   similarity alone can not create a cross-entry connection.
///
/// Nothing here deletes or alters entries; ineligible records stay in
/// the archive untouched.
abstract class MemoryScopePolicy {
  MemoryScopePolicy._();

  /// Live scope, loaded from [MemoryScopeStore] at surface entry points.
  /// Defaults to automatic until an explicit user choice is loaded; the
  /// app never changes it on its own.
  static MemoryScope scope = MemoryScope.automatic;

  /// Whether memory/insight surfaces may show connection claims at all.
  static bool get memoryClaimsAllowed => scope != MemoryScope.off;

  /// Ask mode: the user tapped Connect for the entry being saved right
  /// now. Consumed by the next new-entry save.
  static bool connectApprovedForNextSave = false;

  /// Consumes the pending ask-mode approval (one save only).
  static bool consumeConnectApproval() {
    final approved = connectApprovedForNextSave;
    connectApprovedForNextSave = false;
    return approved;
  }

  /// Whether [record] may feed connection claims under the current scope.
  static bool isRecordConnectionEligible(PressureCheckInRecord record) {
    if (record.treatAsNew || record.keepSeparate) return false;
    if (record.entryAboutness != 'about_me') return false;
    switch (scope) {
      case MemoryScope.off:
        return false;
      case MemoryScope.automatic:
        return true;
      case MemoryScope.ask:
        return record.connectionApproved;
      case MemoryScope.threadOnly:
        return _hasExplicitThreadLinkage(record);
    }
  }

  /// Filters [records] down to the ones connection claims may be built
  /// from under the current scope.
  static List<PressureCheckInRecord> connectionEligible(
    List<PressureCheckInRecord> records,
  ) {
    switch (scope) {
      case MemoryScope.off:
        return const [];
      case MemoryScope.automatic:
        return records
            .where(
              (r) =>
                  !r.treatAsNew &&
                  !r.keepSeparate &&
                  r.entryAboutness == 'about_me',
            )
            .toList();
      case MemoryScope.ask:
        return records
            .where(
              (r) =>
                  !r.treatAsNew &&
                  !r.keepSeparate &&
                  r.entryAboutness == 'about_me' &&
                  r.connectionApproved,
            )
            .toList();
      case MemoryScope.threadOnly:
        return _sharedThreadOnly(
          records.where(
            (r) =>
                !r.treatAsNew &&
                !r.keepSeparate &&
                r.entryAboutness == 'about_me',
          ),
        );
    }
  }

  static bool _hasExplicitThreadLinkage(PressureCheckInRecord record) {
    final hasThread =
        record.archiveThreadId != null && record.archiveThreadId!.isNotEmpty;
    return hasThread || record.contextIds.isNotEmpty;
  }

  /// Thread-only scope: a record is eligible only when one of its
  /// explicit archive-thread ids or context markers is shared with at
  /// least one other record.
  static List<PressureCheckInRecord> _sharedThreadOnly(
    Iterable<PressureCheckInRecord> records,
  ) {
    final list = records.toList();
    final threadCounts = <String, int>{};
    final contextCounts = <String, int>{};
    for (final record in list) {
      final threadId = record.archiveThreadId;
      if (threadId != null && threadId.isNotEmpty) {
        threadCounts[threadId] = (threadCounts[threadId] ?? 0) + 1;
      }
      for (final context in record.contextIds.toSet()) {
        contextCounts[context] = (contextCounts[context] ?? 0) + 1;
      }
    }
    return list.where((r) {
      final sharedThread =
          r.archiveThreadId != null &&
          (threadCounts[r.archiveThreadId!] ?? 0) >= 2;
      final sharedContext = r.contextIds.any(
        (c) => (contextCounts[c] ?? 0) >= 2,
      );
      return sharedThread || sharedContext;
    }).toList();
  }

  @visibleForTesting
  static void resetForTest() {
    scope = MemoryScope.automatic;
    connectApprovedForNextSave = false;
  }
}
