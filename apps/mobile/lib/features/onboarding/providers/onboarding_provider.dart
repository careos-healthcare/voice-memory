import 'dart:async';

import 'package:archiveme_mobile/features/voice/data/voice_journal_pipeline.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Guided prompts. Together they stay inside a 30-second first launch.
const List<String> onboardingPrompts = <String>[
  "Welcome to ArchiveMe. What's top of mind for you right now?",
  'How would you like to feel at the end of each day?',
  "Let's capture this baseline.",
];

/// Tag stored on baseline journal rows.
const String onboardingBaselineTag = 'is_onboarding_baseline';

/// Where a finished onboarding baseline is remembered.
abstract interface class OnboardingCompletionStore {
  Future<bool> isComplete();

  Future<void> markComplete(OnboardingBaseline baseline);

  Future<OnboardingBaseline?> readBaseline();
}

/// In-memory stand-in for tests and for launches before prefs exist.
class MemoryOnboardingCompletionStore implements OnboardingCompletionStore {
  bool complete = false;
  OnboardingBaseline? baseline;

  @override
  Future<bool> isComplete() async => complete;

  @override
  Future<void> markComplete(OnboardingBaseline value) async {
    complete = true;
    baseline = value;
  }

  @override
  Future<OnboardingBaseline?> readBaseline() async => baseline;
}

/// Writes the completion flag and entry ids. The words stay in the journal.
class PrefsOnboardingCompletionStore implements OnboardingCompletionStore {
  PrefsOnboardingCompletionStore(this.prefs);

  final MobilePrefsStore prefs;

  static const idsKey = 'onboardingBaselineIds';

  @override
  Future<bool> isComplete() => prefs.onboardingCompleted;

  @override
  Future<void> markComplete(OnboardingBaseline baseline) async {
    await prefs.setOnboardingCompleted(true);
    await prefs.writeMap(idsKey, <String, Object?>{
      'is_onboarding_baseline': true,
      'coreMemoryId': baseline.coreMemoryId,
      'lifePatternsId': baseline.lifePatternsId,
    });
  }

  @override
  Future<OnboardingBaseline?> readBaseline() async => null;
}

/// Core Memory plus the Life Patterns drawn from the first conversation.
class OnboardingBaseline {
  const OnboardingBaseline({
    required this.coreMemoryId,
    required this.coreMemory,
    required this.lifePatternsId,
    required this.lifePatterns,
    required this.entries,
  });

  final String coreMemoryId;
  final String coreMemory;
  final String lifePatternsId;
  final List<String> lifePatterns;
  final List<JournalEntry> entries;

  bool get isOnboardingBaseline => true;
}

enum OnboardingPhase { prompting, done }

/// Listens for speech or typed lines, then writes the baseline entries.
class OnboardingSession extends ChangeNotifier {
  OnboardingSession({
    this.speech,
    this.levels,
    this.store,
    this.saveEntry,
    this.index,
    this.pace = const Duration(seconds: 8),
    this.markGateComplete,
    DateTime Function()? clock,
    String Function()? idFactory,
  }) : _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? _defaultId {
    _answers = List<String>.filled(onboardingPrompts.length, '');
  }

  final Stream<String>? speech;
  final Stream<double>? levels;
  final OnboardingCompletionStore? store;
  final Future<void> Function(JournalEntry entry)? saveEntry;
  final VoiceInsightIndexer? index;
  final Duration? pace;
  final void Function()? markGateComplete;
  final DateTime Function() _clock;
  final String Function() _idFactory;

  static var _idCount = 0;

  static String _defaultId() {
    _idCount += 1;
    return 'onboarding-$_idCount';
  }

  late final List<String> _answers;
  StreamSubscription<String>? _speechSub;
  StreamSubscription<double>? _levelSub;
  Timer? _paceTimer;
  var _started = false;
  var _finishing = false;

  OnboardingPhase phase = OnboardingPhase.prompting;
  int step = 0;
  bool typing = false;
  double level = 0;
  String transcript = '';
  OnboardingBaseline? baseline;

  String get prompt => onboardingPrompts[step];

  late final OnboardingCompletionStore _resolvedStore =
      store ?? MemoryOnboardingCompletionStore();

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (await _resolvedStore.isComplete()) {
      baseline = await _resolvedStore.readBaseline();
      phase = OnboardingPhase.done;
      notifyListeners();
      return;
    }
    _speechSub = speech?.listen(hear);
    _levelSub = levels?.listen((value) {
      level = value.clamp(0, 1).toDouble();
      notifyListeners();
    });
    _armPace();
    notifyListeners();
  }

  void beginTyping() {
    typing = true;
    _paceTimer?.cancel();
    notifyListeners();
  }

  void hear(String text) {
    final line = text.trim();
    if (line.isEmpty || phase == OnboardingPhase.done) return;
    _answers[step] = line;
    transcript = _answers.where((answer) => answer.trim().isNotEmpty).join(' ');
    notifyListeners();
    _advance();
  }

  void submitTyped(String text) {
    final line = text.trim();
    if (line.isEmpty) {
      skip();
      return;
    }
    typing = false;
    hear(line);
  }

  void tapOrb() {
    if (phase == OnboardingPhase.done) return;
    if (_answers[step].trim().isEmpty) {
      _answers[step] = _tapLine(step);
      transcript = _answers
          .where((answer) => answer.trim().isNotEmpty)
          .join(' ');
    }
    _advance();
  }

  void skip() {
    if (phase == OnboardingPhase.done) return;
    unawaited(finish());
  }

  Future<void> finish() async {
    if (_finishing || phase == OnboardingPhase.done) return;
    _finishing = true;
    _paceTimer?.cancel();
    final lines = _answers
        .map((answer) => answer.trim())
        .where((answer) => answer.isNotEmpty)
        .toList();
    final spoken = lines.join(' ');
    final coreMemory = spoken.isEmpty ? 'A first moment in ArchiveMe.' : spoken;
    final lifePatterns = extractLifePatterns(coreMemory);
    final createdAt = _clock().toUtc();
    final core = _entry(
      id: _idFactory(),
      createdAt: createdAt,
      transcript: coreMemory,
      patterns: lifePatterns,
      captureSource: 'onboarding_core_memory',
    );
    final patternsEntry = _entry(
      id: _idFactory(),
      createdAt: createdAt,
      transcript: lifePatterns.join('. '),
      patterns: lifePatterns,
      captureSource: 'onboarding_life_patterns',
    );
    await saveEntry?.call(core);
    await saveEntry?.call(patternsEntry);
    await index?.call(core, lifePatterns);
    final hook = VoiceInsightHooks.index;
    if (hook != null && hook != index) {
      await hook(core, lifePatterns);
    }
    baseline = OnboardingBaseline(
      coreMemoryId: core.id,
      coreMemory: coreMemory,
      lifePatternsId: patternsEntry.id,
      lifePatterns: lifePatterns,
      entries: <JournalEntry>[core, patternsEntry],
    );
    await _resolvedStore.markComplete(baseline!);
    (markGateComplete ?? onboardingGate.markComplete).call();
    phase = OnboardingPhase.done;
    notifyListeners();
  }

  @override
  void dispose() {
    _paceTimer?.cancel();
    unawaited(_speechSub?.cancel());
    unawaited(_levelSub?.cancel());
    super.dispose();
  }

  void _advance() {
    if (phase == OnboardingPhase.done) return;
    if (step < onboardingPrompts.length - 1) {
      step += 1;
      typing = false;
      _armPace();
      notifyListeners();
      return;
    }
    unawaited(finish());
  }

  void _armPace() {
    _paceTimer?.cancel();
    final delay = pace;
    if (delay == null || typing) return;
    _paceTimer = Timer(delay, tapOrb);
  }

  JournalEntry _entry({
    required String id,
    required DateTime createdAt,
    required String transcript,
    required List<String> patterns,
    required String captureSource,
  }) {
    final summary = patterns.isEmpty ? transcript : patterns.first;
    // Flat factory matches the voice journal pipeline's entry shape.
    // ignore: deprecated_member_use_from_same_package
    return JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      durationSeconds: 0,
      reflection: Reflection(
        mood: 'reflective',
        emotionalIntensity: 1,
        recurringThemes: patterns,
        exactLanguagePattern: summary,
        concreteObservation: summary,
        repeatedSignal: patterns.length > 1 ? patterns[1] : summary,
      ),
      captureContextTag: onboardingBaselineTag,
      captureSource: captureSource,
    );
  }

  static String _tapLine(int step) {
    return switch (step) {
      0 => 'Something is top of mind right now.',
      1 => 'I would like to feel settled by the end of the day.',
      _ => 'This is the baseline to keep.',
    };
  }
}

/// Session for a [ProviderScope]. The screen can also construct its own.
final Provider<OnboardingSession> onboardingSessionProvider =
    Provider.autoDispose<OnboardingSession>((
      ref,
    ) {
      final session = OnboardingSession(
        store: AppServices.isInitialized
            ? PrefsOnboardingCompletionStore(AppServices.instance.prefs)
            : MemoryOnboardingCompletionStore(),
      );
      ref.onDispose(session.dispose);
      return session;
    });
