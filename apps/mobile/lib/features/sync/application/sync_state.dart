import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:flutter/foundation.dart';

enum SyncPhase { idle, syncing, completed, failed }

@immutable
class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastResult,
    this.lastFailure,
    this.partialPushed = 0,
  });

  final SyncPhase phase;
  final SyncResult? lastResult;
  final ApiFailure? lastFailure;
  final int partialPushed;

  SyncState copyWith({
    SyncPhase? phase,
    SyncResult? lastResult,
    bool clearLastResult = false,
    ApiFailure? lastFailure,
    bool clearLastFailure = false,
    int? partialPushed,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      lastFailure: clearLastFailure ? null : (lastFailure ?? this.lastFailure),
      partialPushed: partialPushed ?? this.partialPushed,
    );
  }
}