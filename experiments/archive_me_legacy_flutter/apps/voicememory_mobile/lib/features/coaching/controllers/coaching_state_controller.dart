import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/journal_entry.dart';
import '../../../services/app_services_providers.dart';
import '../services/coaching_engine_service.dart';

class CoachingState {
  const CoachingState({
    this.insight,
    this.isAnalyzing = false,
    this.errorMessage,
  });

  final CoachingInsight? insight;
  final bool isAnalyzing;
  final String? errorMessage;

  CoachingState copyWith({
    CoachingInsight? insight,
    bool? isAnalyzing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CoachingState(
      insight: insight ?? this.insight,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final coachingEngineServiceProvider = Provider<CoachingEngineService>((ref) {
  return CoachingEngineService(journalStore: ref.watch(journalStoreProvider));
});

final coachingStateControllerProvider =
    NotifierProvider.autoDispose<CoachingStateController, CoachingState>(
      CoachingStateController.new,
    );

class CoachingStateController extends Notifier<CoachingState> {
  StreamSubscription<List<JournalEntry>>? _journalSubscription;
  Set<String>? _knownEntryIds;
  int _analysisRevision = 0;

  @override
  CoachingState build() {
    final journalStore = ref.watch(journalStoreProvider);
    _journalSubscription = journalStore.watchAll().listen(
      _handleJournalEntries,
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(
          isAnalyzing: false,
          errorMessage: 'Coaching analysis is temporarily unavailable.',
        );
      },
    );
    ref.onDispose(() {
      unawaited(_journalSubscription?.cancel());
      _journalSubscription = null;
    });
    return const CoachingState();
  }

  Future<void> refreshDailyBriefing() async {
    final revision = ++_analysisRevision;
    state = state.copyWith(isAnalyzing: true, clearError: true);
    try {
      final insight = await ref
          .read(coachingEngineServiceProvider)
          .generateDailyBriefing();
      if (revision != _analysisRevision || !ref.mounted) return;
      state = CoachingState(insight: insight);
    } catch (_) {
      if (revision != _analysisRevision || !ref.mounted) return;
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: 'Coaching analysis is temporarily unavailable.',
      );
    }
  }

  void _handleJournalEntries(List<JournalEntry> entries) {
    final currentIds = entries.map((entry) => entry.id).toSet();
    final previousIds = _knownEntryIds;
    _knownEntryIds = currentIds;
    final hasNewEntry =
        previousIds == null || currentIds.difference(previousIds).isNotEmpty;
    if (!hasNewEntry) return;
    unawaited(_analyze(entries));
  }

  Future<void> _analyze(List<JournalEntry> entries) async {
    final revision = ++_analysisRevision;
    state = state.copyWith(isAnalyzing: true, clearError: true);
    try {
      final recent = entries.take(30).toList(growable: false);
      final engine = ref.read(coachingEngineServiceProvider);
      final pattern = await engine.analyzePattern(recent);
      final insight = pattern ?? await engine.generateDailyBriefing();
      if (revision != _analysisRevision || !ref.mounted) return;
      state = CoachingState(insight: insight);
    } catch (_) {
      if (revision != _analysisRevision || !ref.mounted) return;
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: 'Coaching analysis is temporarily unavailable.',
      );
    }
  }
}
