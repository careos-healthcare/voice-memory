import '../../models/journal_entry.dart';
import '../acquisition/audience_wedge_model.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../loop_mode/loop_mode_engine.dart';
import '../loop_mode/loop_mode_model.dart';
import '../../product/loop_mode_copy.dart';
import '../first_session/first_session_pattern_model.dart';
import '../post_save_insight/selected_signal_model.dart';
import '../post_save_insight/signal_feedback_model.dart';
import 'interpretation_read_model.dart';

/// Deterministic local engine for evidence-grounded post-save reads.
class InterpretationQualityEngine {
  const InterpretationQualityEngine();

  static final _vagueOnlyPattern = RegExp(
    r'\b(feel|feeling|felt|weird|off|bad|fine|okay|ok|strange|unsettled|unsure)\b',
    caseSensitive: false,
  );

  static const _actionWords = {
    'said',
    'say',
    'agreed',
    'agree',
    'avoid',
    'avoiding',
    'help',
    'helped',
    'tell',
    'told',
    'prove',
    'proving',
    'choose',
    'chose',
    'disappoint',
    'pressure',
    'responsible',
    'responsibility',
    'rest',
    'tired',
    'drained',
  };

  InterpretationResult build({
    required JournalEntry latestEntry,
    List<JournalEntry> priorEntries = const [],
    List<PostSaveSignalFeedback> feedback = const [],
    SelectedSignalRecord? selectedSignal,
    FirstSessionPattern? patternHint,
    AudienceWedge? audienceWedge,
    LoopMode? activeLoop,
    String? languageCode,
  }) {
    final text = _entryText(latestEntry);
    if (text.trim().isEmpty ||
        ComparableEvidenceText.entryHasPendingTranscript(latestEntry)) {
      return const InterpretationResult(
        reads: const [],
        needsClearerMoment: true,
        clearerMomentTitle: 'Transcript pending',
        clearerMomentPrompt:
            'This moment is saved, but ArchiveMe needs words before suggesting a read.',
      );
    }

    final normalized = _normalize(text);
    final fragments = _extractFragments(text);
    final tags = _extractTags(normalized);
    const loopEngine = LoopModeEngine();

    if (activeLoop != null &&
        activeLoop.isFullyImplementedLoop &&
        !loopEngine.textSupports(activeLoop, normalized) &&
        !_isTooVague(normalized, fragments, tags)) {
      return InterpretationResult(
        reads: const [],
        needsClearerMoment: true,
        clearerMomentTitle: loopEngine.unsupportedTitle(activeLoop),
        clearerMomentPrompt: loopEngine.unsupportedPrompt(activeLoop),
        loopUnsupported: true,
      );
    }

    if (_isTooVague(normalized, fragments, tags)) {
      return InterpretationResult(
        reads: const [],
        needsClearerMoment: true,
        clearerMomentPrompt:
            'What happened, what did you do, and what felt heavy?',
      );
    }

    final rejectedTitles = _rejectedTitles(feedback);
    final rejectedIds = _rejectedIds(feedback, rejectedTitles);
    final priorTexts = priorEntries.map(_entryText).where((t) => t.isNotEmpty);
    final priorTags = priorTexts.map(_normalize).map(_extractTags).toList();

    final scored = <_ScoredRead>[];
    for (final template in _templates) {
      final score = _scoreTemplate(template, normalized, fragments, tags);
      if (score.total <= 0) continue;

      var adjusted = score.total;
      if (rejectedIds.contains(template.id)) adjusted -= 12;
      if (rejectedTitles.any((t) => _titleSimilar(t, template.title))) {
        adjusted -= 8;
      }
      if (feedback.any(
        (f) =>
            f.action == PostSaveSignalAction.accepted &&
            f.categoryId == template.categoryId,
      )) {
        adjusted += 3;
      }

      final archiveOverlap = _archiveOverlap(
        template,
        tags,
        priorTags,
        selectedSignal,
      );
      if (archiveOverlap > 0.45) adjusted += 6;
      if (archiveOverlap > 0.2 && archiveOverlap <= 0.45) adjusted += 2;

      final specificity = _specificityFor(template, score, tags);
      final strength = _strengthLabel(
        specificity: specificity,
        reflectionCount: priorEntries.length + 1,
        archiveOverlap: archiveOverlap,
        evidenceCount: fragments.length + tags.length,
      );

      final why = _whyThisRead(template, fragments, tags, archiveOverlap);
      final deep = _deepContent(template, fragments, tags, archiveOverlap);

      scored.add(
        _ScoredRead(
          read: InterpretationRead(
            id: template.id,
            title: template.title,
            shortRead: template.shortRead,
            evidenceFragments: fragments.take(3).toList(),
            evidenceTags: tags.take(3).toList(),
            specificityLevel: specificity,
            strengthLabel: strength,
            whyThisRead: why,
            whatWouldConfirm: deep.confirm,
            whatWouldContradict: deep.contradict,
            nextEvidencePrompt: deep.nextPrompt,
            mightMean: deep.mightMean,
            evidenceUsed: deep.evidenceUsed,
            alternativeAngleIds: template.alternativeIds,
            source: archiveOverlap >= 0.45
                ? InterpretationSource.archiveRepeat
                : (rejectedIds.contains(template.id)
                      ? InterpretationSource.feedbackAdjusted
                      : InterpretationSource.latestOnly),
            categoryId: template.categoryId,
            angleCategory: template.angleCategory,
            rankScore: adjusted,
            safetyFlags: fragments.isEmpty
                ? const [InterpretationSafetyFlag.unsupported]
                : const [],
          ),
          score: adjusted,
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    if (patternHint != null && scored.isNotEmpty) {
      final hintCat = patternHint.categoryId;
      final hintBoost = scored.where((s) => s.read.categoryId == hintCat);
      if (hintBoost.isNotEmpty) {
        final top = hintBoost.first;
        scored.remove(top);
        scored.insert(0, _ScoredRead(read: top.read, score: top.score + 2));
      }
    }

    _applyAudienceWedgeBoost(scored, audienceWedge, normalized);
    _applyLoopModeBoost(scored, activeLoop, normalized);

    scored.sort((a, b) => b.score.compareTo(a.score));

    final topReads = scored.take(3).map((s) => s.read).toList();

    if (topReads.isEmpty ||
        topReads.every(
          (r) => r.specificityLevel == InterpretationSpecificityLevel.low,
        )) {
      return InterpretationResult(
        reads: topReads,
        needsClearerMoment: true,
        clearerMomentPrompt:
            'What happened, what did you do, and what felt heavy?',
      );
    }

    final archiveRepeat = topReads.any(
      (r) => r.source == InterpretationSource.archiveRepeat,
    );
    final changedAngle =
        priorEntries.isNotEmpty &&
        topReads.isNotEmpty &&
        !archiveRepeat &&
        priorTags.isNotEmpty &&
        _tagsOverlap(tags, priorTags.last) < 0.25;

    return InterpretationResult(
      reads: topReads,
      needsClearerMoment: false,
      archiveRepeatDetected: archiveRepeat,
      changedAngleDetected: changedAngle,
    );
  }

  /// Plausible competing reads for alternative-angle flow.
  List<InterpretationRead> alternativesFor({
    required String primaryReadId,
    required String normalizedText,
    List<String> fragments = const [],
    List<String> tags = const [],
    int max = 2,
  }) {
    final primaryTemplate = _templates
        .where((t) => t.id == primaryReadId)
        .firstOrNull;
    if (primaryTemplate == null) return const [];

    final pool = _templates
        .where((t) => primaryTemplate.alternativeIds.contains(t.id))
        .toList();
    final out = <InterpretationRead>[];
    for (final template in pool) {
      if (out.length >= max) break;
      final score = _scoreTemplate(template, normalizedText, fragments, tags);
      if (score.total <= 0) continue;
      final deep = _deepContent(template, fragments, tags, 0);
      out.add(
        InterpretationRead(
          id: '${template.id}_alt',
          title: template.title,
          shortRead: template.shortRead,
          evidenceFragments: fragments.take(3).toList(),
          evidenceTags: tags.take(3).toList(),
          specificityLevel: _specificityFor(template, score, tags),
          strengthLabel: 'Early signal',
          whyThisRead: template.shortRead,
          whatWouldConfirm: deep.confirm,
          whatWouldContradict: deep.contradict,
          nextEvidencePrompt: deep.nextPrompt,
          mightMean: deep.mightMean,
          evidenceUsed: deep.evidenceUsed,
          alternativeAngleIds: const [],
          source: InterpretationSource.latestOnly,
          categoryId: template.categoryId,
          angleCategory: template.angleCategory,
        ),
      );
    }
    return out;
  }

  String _entryText(JournalEntry entry) {
    return ComparableEvidenceText.userText(entry);
  }

  String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  bool _isTooVague(
    String normalized,
    List<String> fragments,
    List<String> tags,
  ) {
    if (normalized.length < 18) return true;
    if (tags.isEmpty && fragments.isEmpty) return true;
    final words = normalized.split(RegExp(r'\s+')).where((w) => w.length > 2);
    if (words.length < 4) return true;
    final vagueHits = _vagueOnlyPattern.allMatches(normalized).length;
    final concreteHits = tags.length + fragments.length;
    return vagueHits >= 2 && concreteHits <= 1;
  }

  List<String> _extractTags(String normalized) {
    const allTerms = {
      'said yes': 'saying yes',
      'saying yes': 'saying yes',
      'agreed': 'agreeing',
      'agree': 'agreeing',
      'disappoint': 'disappoint',
      'pressure': 'pressure',
      'responsible': 'responsibility',
      'responsibility': 'responsibility',
      'help': 'help',
      'prove': 'prove',
      'proving': 'prove',
      'enough': 'enough',
      'behind': 'behind',
      'achievement': 'achievement',
      'impressive': 'achievement',
      'control': 'control',
      'plan': 'plan',
      'perfect': 'perfect',
      'avoid': 'avoid',
      'avoiding': 'avoid',
      'conversation': 'conversation',
      'tell': 'say',
      'told': 'say',
      'rest': 'rest',
      'tired': 'tired',
      'drained': 'drained',
      'exhausted': 'drained',
      'worry': 'worry',
      'anxious': 'worry',
      'anxiety': 'worry',
      'guilt': 'guilt',
      'guilty': 'guilt',
      'capacity': 'capacity',
      'time': 'time pressure',
    };
    final out = <String>[];
    for (final entry in allTerms.entries) {
      if (normalized.contains(entry.key)) {
        if (!out.contains(entry.value)) out.add(entry.value);
      }
    }
    return out;
  }

  List<String> _extractFragments(String text) {
    if (text.trim().isEmpty) return const [];
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentences = normalized.split(RegExp(r'(?<=[.!?])\s+'));
    final out = <String>[];
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.length < 8) continue;
      final lower = trimmed.toLowerCase();
      final hasSignal = _actionWords.any(lower.contains);
      if (!hasSignal && trimmed.split(' ').length < 5) continue;
      final fragment = trimmed.length <= 72
          ? trimmed
          : '${trimmed.substring(0, 69)}…';
      if (!out.contains(fragment)) out.add(fragment);
      if (out.length >= 3) break;
    }
    if (out.isEmpty && normalized.length >= 12) {
      out.add(
        normalized.length <= 72
            ? normalized
            : '${normalized.substring(0, 69)}…',
      );
    }
    return out;
  }

  _ScoreBreakdown _scoreTemplate(
    _ReadTemplate template,
    String normalized,
    List<String> fragments,
    List<String> tags,
  ) {
    var total = 0.0;
    var phraseHits = 0;
    var keywordHits = 0;

    for (final phrase in template.phrases) {
      if (normalized.contains(phrase.toLowerCase())) {
        total += 4;
        phraseHits++;
      }
    }
    for (final kw in template.keywords) {
      if (RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(normalized)) {
        total += 2;
        keywordHits++;
      }
    }
    for (final action in _actionWords) {
      if (normalized.contains(action)) total += 0.5;
    }
    if (tags.any(template.tagBoost.contains)) total += 2;
    if (fragments.isNotEmpty) total += 1;

    if (template.requiredAny.isNotEmpty) {
      final any = template.requiredAny.any(normalized.contains);
      if (!any) total *= 0.4;
    }

    return _ScoreBreakdown(
      total: total,
      phraseHits: phraseHits,
      keywordHits: keywordHits,
    );
  }

  InterpretationSpecificityLevel _specificityFor(
    _ReadTemplate template,
    _ScoreBreakdown score,
    List<String> tags,
  ) {
    if (score.phraseHits >= 1 && score.keywordHits >= 2 && tags.length >= 2) {
      return InterpretationSpecificityLevel.high;
    }
    if (score.phraseHits >= 1 || score.keywordHits >= 2 || tags.length >= 2) {
      return InterpretationSpecificityLevel.medium;
    }
    return InterpretationSpecificityLevel.low;
  }

  String _strengthLabel({
    required InterpretationSpecificityLevel specificity,
    required int reflectionCount,
    required double archiveOverlap,
    required int evidenceCount,
  }) {
    if (reflectionCount >= 4 &&
        specificity == InterpretationSpecificityLevel.high &&
        archiveOverlap >= 0.55 &&
        evidenceCount >= 3) {
      return 'Strong pattern';
    }
    if (reflectionCount >= 3 && archiveOverlap >= 0.35 && evidenceCount >= 2) {
      return 'Getting clearer';
    }
    if (archiveOverlap >= 0.45 ||
        (reflectionCount >= 2 && evidenceCount >= 2)) {
      return 'Possible repeat';
    }
    return 'Early signal';
  }

  String _whyThisRead(
    _ReadTemplate template,
    List<String> fragments,
    List<String> tags,
    double archiveOverlap,
  ) {
    if (archiveOverlap >= 0.45) {
      return 'Both moments involve ${template.repeatHint}.';
    }
    if (tags.isNotEmpty) {
      return 'You mentioned ${tags.take(3).join(', ')}.';
    }
    if (fragments.isNotEmpty) {
      return template.shortRead;
    }
    return template.shortRead;
  }

  _DeepContent _deepContent(
    _ReadTemplate template,
    List<String> fragments,
    List<String> tags,
    double archiveOverlap,
  ) {
    final evidenceParts = <String>[
      if (tags.isNotEmpty) 'You mentioned ${tags.take(3).join(', ')}.',
      if (fragments.isNotEmpty) 'From your moment: "${fragments.first}".',
    ];
    final evidenceUsed = evidenceParts.isNotEmpty
        ? evidenceParts.join(' ')
        : template.evidenceFallback;

    return _DeepContent(
      mightMean: template.mightMean,
      confirm: archiveOverlap >= 0.45
          ? template.confirmRepeat
          : template.confirm,
      contradict: template.contradict,
      nextPrompt: template.nextPrompt,
      evidenceUsed: evidenceUsed,
    );
  }

  double _archiveOverlap(
    _ReadTemplate template,
    List<String> latestTags,
    List<List<String>> priorTags,
    SelectedSignalRecord? selected,
  ) {
    if (priorTags.isEmpty && selected == null) return 0;
    var best = 0.0;
    for (final prior in priorTags) {
      best = best > _tagsOverlap(latestTags, prior)
          ? best
          : _tagsOverlap(latestTags, prior);
      if (_clusterOverlap(latestTags, prior) >= 0.35) {
        best = best > 0.5 ? best : 0.5;
      }
    }
    if (selected != null &&
        (selected.categoryId == template.categoryId ||
            _titleSimilar(selected.title, template.title))) {
      best = best > 0.5 ? best : 0.55;
    }
    return best;
  }

  double _clusterOverlap(List<String> a, List<String> b) {
    const clusters = [
      {
        'saying yes',
        'agreeing',
        'pressure',
        'disappoint',
        'guilt',
        'help',
        'responsibility',
        'time pressure',
      },
      {'prove', 'enough', 'behind', 'achievement'},
      {'avoid', 'say', 'conversation'},
      {'rest', 'tired', 'drained', 'worry'},
    ];
    for (final cluster in clusters) {
      final aHit = a.any(cluster.contains);
      final bHit = b.any(cluster.contains);
      if (aHit && bHit) return 0.6;
    }
    return 0;
  }

  double _tagsOverlap(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final shared = a.toSet().intersection(b.toSet()).length;
    return shared / a.toSet().union(b.toSet()).length;
  }

  Set<String> _rejectedTitles(List<PostSaveSignalFeedback> feedback) {
    return feedback
        .where((f) => f.action == PostSaveSignalAction.rejected)
        .map((f) => f.signalTitle.toLowerCase())
        .toSet();
  }

  void _applyLoopModeBoost(
    List<_ScoredRead> scored,
    LoopMode? activeLoop,
    String normalizedText,
  ) {
    if (activeLoop == null || !activeLoop.isFullyImplementedLoop) return;
    const engine = LoopModeEngine();
    if (!engine.textSupports(activeLoop, normalizedText)) return;
    final preferred = engine.preferredTemplateIds(activeLoop).toSet();
    for (var i = 0; i < scored.length; i++) {
      if (preferred.contains(scored[i].read.id)) {
        final item = scored[i];
        scored[i] = _ScoredRead(read: item.read, score: item.score + 12);
      }
    }
  }

  void _applyAudienceWedgeBoost(
    List<_ScoredRead> scored,
    AudienceWedge? audienceWedge,
    String normalizedText,
  ) {
    if (audienceWedge == null ||
        audienceWedge == AudienceWedge.notSureYet ||
        !audienceWedge.textSupports(normalizedText)) {
      return;
    }
    final boosted = <int>[];
    for (var i = 0; i < scored.length; i++) {
      if (audienceWedge.templateIds.contains(scored[i].read.id)) {
        boosted.add(i);
      }
    }
    for (final i in boosted) {
      final item = scored[i];
      scored[i] = _ScoredRead(read: item.read, score: item.score + 10);
    }
  }

  Set<String> _rejectedIds(
    List<PostSaveSignalFeedback> feedback,
    Set<String> rejectedTitles,
  ) {
    final ids = feedback
        .where((f) => f.action == PostSaveSignalAction.rejected)
        .map((f) => f.signalId)
        .toSet();
    for (final template in _templates) {
      if (rejectedTitles.any((t) => _titleSimilar(t, template.title))) {
        ids.add(template.id);
      }
    }
    return ids;
  }

  bool _titleSimilar(String a, String b) {
    final na = a.toLowerCase().trim();
    final nb = b.toLowerCase().trim();
    if (na == nb) return true;
    final ta = na.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    final tb = nb.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    if (ta.isEmpty || tb.isEmpty) return false;
    final shared = ta.intersection(tb).length;
    return shared / ta.union(tb).length >= 0.5;
  }

  static const List<_ReadTemplate> _templates = [
    _ReadTemplate(
      id: 'saying_yes_capacity',
      title: 'Saying yes before checking your capacity',
      shortRead:
          'This may be about agreeing before you know whether you have room.',
      categoryId: 'responsibility',
      angleCategory: 'behaviour',
      phrases: ['said yes', 'saying yes', 'agreed to', 'agreed to help'],
      keywords: ['yes', 'agreed', 'agree', 'help', 'time', 'capacity'],
      requiredAny: ['yes', 'agreed', 'agree', 'help'],
      tagBoost: {'saying yes', 'agreeing', 'help', 'pressure', 'time pressure'},
      repeatHint: 'agreeing before checking what it costs you',
      mightMean:
          'This may be less about the task itself and more about agreeing before you know whether you have room.',
      confirm:
          'You say yes quickly, feel pressure afterward, or agree before checking time or energy.',
      confirmRepeat:
          'This keeps showing up around help, guilt, pressure, or disappointing someone.',
      contradict:
          'Your next moments show you chose freely and still had capacity.',
      nextPrompt:
          'When did you next agree before checking whether you had capacity?',
      evidenceFallback: 'You mentioned agreeing or pressure around saying yes.',
      alternativeIds: ['disappoint_someone', 'avoid_saying_no'],
    ),
    _ReadTemplate(
      id: 'disappoint_someone',
      title: 'Trying not to disappoint someone',
      shortRead:
          'This may be about fear of letting someone down more than the task itself.',
      categoryId: 'relationship',
      angleCategory: 'relationship',
      phrases: [
        'disappoint',
        'let down',
        'let them down',
        'not want to disappoint',
      ],
      keywords: ['disappoint', 'guilt', 'guilty', 'help', 'agreed'],
      requiredAny: ['disappoint', 'let down'],
      tagBoost: {'disappoint', 'guilt', 'help', 'agreeing'},
      repeatHint: 'not wanting to disappoint someone',
      mightMean:
          'This may be less about what they asked and more about not wanting to let them down.',
      confirm:
          'You agree, stay quiet, or take on more to avoid disappointing someone.',
      confirmRepeat:
          'This keeps showing up when someone else is involved and guilt shows up fast.',
      contradict:
          'Your next moments feel more about your own choice than fear of letting someone down.',
      nextPrompt:
          'When did you last agree mainly to avoid disappointing someone?',
      evidenceFallback: 'You mentioned disappointing someone or guilt.',
      alternativeIds: ['saying_yes_capacity', 'avoid_saying_no'],
    ),
    _ReadTemplate(
      id: 'responsibility_before_help',
      title: 'Taking responsibility before asking for help',
      shortRead:
          'This may be about carrying something alone before asking for support.',
      categoryId: 'responsibility',
      angleCategory: 'control',
      phrases: [
        'take responsibility',
        'taking responsibility',
        'before asking',
        'asking for help',
        'carrying',
      ],
      keywords: ['responsible', 'responsibility', 'alone', 'help', 'ask'],
      requiredAny: ['responsible', 'responsibility', 'help', 'ask'],
      tagBoost: {'responsibility', 'help', 'pressure'},
      repeatHint: 'taking responsibility before asking for help',
      mightMean:
          'You may be carrying more than you need before asking for support.',
      confirm:
          'You handle things alone, say yes quickly, or ask for help late.',
      confirmRepeat:
          'Both moments may involve responsibility showing up before support.',
      contradict:
          'You pause, ask for help early, or leave space without guilt.',
      nextPrompt:
          'What happened right before you took responsibility for something?',
      evidenceFallback: 'You mentioned responsibility, help, or pressure.',
      alternativeIds: ['saying_yes_capacity', 'rest_but_more'],
    ),
    _ReadTemplate(
      id: 'achievement_feel_safe',
      title: 'Using achievement to feel safe',
      shortRead:
          'This may be about leaning on output or achievement before you feel settled.',
      categoryId: 'selfDoubt',
      angleCategory: 'work/ambition',
      phrases: [
        'feel safe',
        'achievement',
        'productive',
        'impressive',
        'success',
      ],
      keywords: [
        'achievement',
        'impressive',
        'success',
        'productive',
        'work',
        'output',
        'safe',
      ],
      requiredAny: ['achievement', 'impressive', 'success', 'productive'],
      tagBoost: {'achievement', 'impressive', 'productive', 'work'},
      repeatHint: 'using achievement to feel safe',
      mightMean:
          'You may be using achievement or output to feel okay before you can rest.',
      confirm:
          'You push for impressive results, stay productive, or measure worth through output.',
      confirmRepeat:
          'Both moments may involve achievement or productivity before ease.',
      contradict:
          'You work from interest, feel satisfied, or stop without guilt.',
      nextPrompt: 'What would have felt unsafe if you stopped earlier?',
      evidenceFallback: 'You mentioned achievement, productivity, or output.',
      alternativeIds: ['prove_enough', 'ignoring_rest_unsafe'],
    ),
    _ReadTemplate(
      id: 'ignoring_rest_unsafe',
      title: 'Ignoring rest because stopping feels unsafe',
      shortRead:
          'This may be about pushing past rest because stopping feels risky.',
      categoryId: 'burnout',
      angleCategory: 'emotion',
      phrases: [
        'could not stop',
        "couldn't stop",
        'keep going',
        'unsafe to stop',
        'rest feels',
      ],
      keywords: [
        'rest',
        'stop',
        'stopping',
        'tired',
        'guilt',
        'behind',
        'keep going',
        'more',
      ],
      requiredAny: ['rest', 'stop', 'tired', 'keep going'],
      tagBoost: {'rest', 'stop', 'tired', 'behind', 'guilt'},
      repeatHint: 'ignoring rest because stopping feels unsafe',
      mightMean:
          'You may keep going because stopping feels unsafe, guilty, or behind.',
      confirm:
          'You skip rest, keep working, or feel behind when you try to stop.',
      confirmRepeat:
          'Both moments may involve rest guilt or pressure to keep going.',
      contradict:
          'You rest without guilt, stop when enough is done, or feel satisfied.',
      nextPrompt: 'What did stopping feel like it would cost you?',
      evidenceFallback:
          'You mentioned rest, stopping, tiredness, or keeping going.',
      alternativeIds: ['prove_enough', 'achievement_feel_safe'],
    ),
    _ReadTemplate(
      id: 'prove_enough',
      title: 'Trying to prove you are doing enough',
      shortRead:
          'This may be about measuring yourself against a standard that feels hard to reach.',
      categoryId: 'selfDoubt',
      angleCategory: 'work/ambition',
      phrases: [
        'not enough',
        'good enough',
        'falling behind',
        'prove',
        'proving',
      ],
      keywords: [
        'prove',
        'proving',
        'enough',
        'behind',
        'achievement',
        'impressive',
        'compare',
      ],
      requiredAny: ['prove', 'enough', 'behind', 'achievement'],
      tagBoost: {'prove', 'enough', 'behind', 'achievement'},
      repeatHint: 'trying to prove you are doing enough',
      mightMean:
          'You may be trying to do more to feel like you are keeping up or enough.',
      confirm: 'You compare yourself, push harder, or doubt your pace.',
      confirmRepeat:
          'Both moments may involve proving, comparing, or feeling behind.',
      contradict:
          'You trust your pace or feel steady without proving anything.',
      nextPrompt: 'What would enough look like in this situation?',
      evidenceFallback: 'You mentioned proving, enough, or falling behind.',
      alternativeIds: ['stay_in_control', 'saying_yes_capacity'],
    ),
    _ReadTemplate(
      id: 'stay_in_control',
      title: 'Trying to stay in control before you feel safe',
      shortRead:
          'This may be about planning or holding things together before you feel settled.',
      categoryId: 'selfDoubt',
      angleCategory: 'control',
      phrases: ['stay in control', 'in control', 'need to control'],
      keywords: ['control', 'plan', 'perfect', 'safe', 'manage'],
      requiredAny: ['control', 'plan', 'perfect'],
      tagBoost: {'control', 'plan', 'perfect'},
      repeatHint: 'trying to stay in control',
      mightMean:
          'This may be less about the situation and more about needing things to feel managed first.',
      confirm:
          'You plan tightly, fix things early, or struggle when things feel uncertain.',
      confirmRepeat:
          'Both moments may involve control or planning before ease.',
      contradict:
          'Your next moments feel more flexible, curious, or unplanned.',
      nextPrompt:
          'What felt unsafe or uncertain right before you tightened control?',
      evidenceFallback:
          'You mentioned control, planning, or needing things settled.',
      alternativeIds: ['prove_enough', 'avoid_conversation'],
    ),
    _ReadTemplate(
      id: 'avoid_conversation',
      title: 'Avoiding a direct conversation',
      shortRead: 'This may be about not saying what you need directly yet.',
      categoryId: 'avoidance',
      angleCategory: 'behaviour',
      phrases: [
        'avoid telling',
        'avoid saying',
        'avoiding telling',
        'avoiding saying',
        'did not say',
        "didn't say",
      ],
      keywords: ['avoid', 'avoiding', 'conversation', 'tell', 'say', 'direct'],
      requiredAny: ['avoid', 'tell', 'say'],
      tagBoost: {'avoid', 'say', 'conversation'},
      repeatHint: 'avoiding saying something directly',
      mightMean:
          'Putting off a direct conversation may be protecting you from tension or rejection.',
      confirm: 'You delay saying what you need, feel stuck, or talk around it.',
      confirmRepeat: 'Both moments may involve something left unsaid.',
      contradict: 'You say what you need directly and feel clearer afterward.',
      nextPrompt: 'What did you avoid saying directly?',
      evidenceFallback: 'You mentioned avoiding saying or telling something.',
      alternativeIds: ['disappoint_someone', 'stay_in_control'],
    ),
    _ReadTemplate(
      id: 'rest_but_more',
      title: 'Wanting rest but choosing more responsibility',
      shortRead:
          'This may be about low energy meeting another yes or obligation.',
      categoryId: 'burnout',
      angleCategory: 'emotion',
      phrases: ['no time', 'did not have time', "didn't have time"],
      keywords: ['tired', 'rest', 'drained', 'exhausted', 'more', 'yes'],
      requiredAny: ['tired', 'rest', 'drained', 'exhausted'],
      tagBoost: {'rest', 'tired', 'drained', 'saying yes'},
      repeatHint: 'wanting rest but taking on more anyway',
      mightMean:
          'Low energy may be shaping what you agree to even when you need rest.',
      confirm: 'You say yes while tired, skip rest, or feel flat afterward.',
      confirmRepeat:
          'Both moments may involve tiredness and still taking on more.',
      contradict: 'You rest without guilt or protect energy before committing.',
      nextPrompt: 'What would you drop if you had more energy today?',
      evidenceFallback:
          'You mentioned tiredness, rest, or running low on energy.',
      alternativeIds: ['saying_yes_capacity', 'responsibility_before_help'],
    ),
    _ReadTemplate(
      id: 'worry_returning',
      title: 'The same worry returning',
      shortRead: 'A worry may be taking up more space than you want it to.',
      categoryId: 'worry',
      angleCategory: 'emotion',
      phrases: [
        'same worry',
        'keep worrying',
        'cannot switch off',
        'overthinking',
      ],
      keywords: [
        'worry',
        'worried',
        'anxious',
        'anxiety',
        'stress',
        'replaying',
      ],
      requiredAny: ['worry', 'anxious', 'anxiety', 'stress'],
      tagBoost: {'worry'},
      repeatHint: 'the same worry returning',
      mightMean:
          'A worry may be staying with you longer than the moment itself.',
      confirm: 'The same worry returns when you try to switch off or move on.',
      confirmRepeat: 'Both moments may involve the same worry taking up space.',
      contradict: 'You notice the worry but can move on without replaying it.',
      nextPrompt: 'When does this worry show up most — and what triggers it?',
      evidenceFallback: 'You mentioned worry, stress, or replaying thoughts.',
      alternativeIds: ['stay_in_control', 'prove_enough'],
    ),
    _ReadTemplate(
      id: 'avoid_saying_no',
      title: 'Avoiding the discomfort of saying no',
      shortRead:
          'This may be about sidestepping no because it feels uncomfortable.',
      categoryId: 'avoidance',
      angleCategory: 'behaviour',
      phrases: ['could not say no', "couldn't say no", 'hard to say no'],
      keywords: ['no', 'yes', 'agreed', 'pressure', 'guilt'],
      requiredAny: ['no', 'yes', 'agreed'],
      tagBoost: {'agreeing', 'guilt', 'pressure'},
      repeatHint: 'avoiding the discomfort of saying no',
      mightMean:
          'Saying yes may be easier right now than facing what no would feel like.',
      confirm: 'You agree quickly, delay no, or feel tension after saying yes.',
      confirmRepeat: 'Both moments may involve yes coming before a real no.',
      contradict: 'Your next moments show you said no and felt relief.',
      nextPrompt: 'What would have made saying no feel possible?',
      evidenceFallback: 'You mentioned agreeing, pressure, or guilt around no.',
      alternativeIds: ['saying_yes_capacity', 'disappoint_someone'],
    ),
    _ReadTemplate(
      id: 'repeating_habit',
      title: 'Repeating the same habit',
      shortRead:
          'This may be about doing something again even though you noticed it.',
      categoryId: 'habit',
      angleCategory: 'behaviour',
      phrases: ['did again', 'keep doing', 'same habit', 'noticed it'],
      keywords: ['again', 'repeat', 'habit', 'noticed', 'keep', 'same'],
      requiredAny: ['again', 'repeat', 'habit', 'noticed'],
      tagBoost: {'again', 'repeat', 'habit', 'noticed'},
      repeatHint: 'repeating the same habit',
      mightMean:
          'You may be running the same move again even after you noticed it.',
      confirm:
          'You do it again soon, notice it while it happens, or feel stuck in the same move.',
      confirmRepeat:
          'Both moments may involve the same habit showing up again.',
      contradict:
          'Your next moments show you paused, changed the move, or broke the loop.',
      nextPrompt: 'What did you do again even though you noticed it?',
      evidenceFallback:
          'You mentioned doing something again or repeating a habit.',
      alternativeIds: ['avoid_conversation', 'saying_yes_capacity'],
    ),
  ];
}

class _ReadTemplate {
  const _ReadTemplate({
    required this.id,
    required this.title,
    required this.shortRead,
    required this.categoryId,
    required this.angleCategory,
    required this.phrases,
    required this.keywords,
    required this.requiredAny,
    required this.tagBoost,
    required this.repeatHint,
    required this.mightMean,
    required this.confirm,
    required this.confirmRepeat,
    required this.contradict,
    required this.nextPrompt,
    required this.evidenceFallback,
    required this.alternativeIds,
  });

  final String id;
  final String title;
  final String shortRead;
  final String categoryId;
  final String angleCategory;
  final List<String> phrases;
  final List<String> keywords;
  final List<String> requiredAny;
  final Set<String> tagBoost;
  final String repeatHint;
  final String mightMean;
  final String confirm;
  final String confirmRepeat;
  final String contradict;
  final String nextPrompt;
  final String evidenceFallback;
  final List<String> alternativeIds;
}

class _ScoreBreakdown {
  const _ScoreBreakdown({
    required this.total,
    required this.phraseHits,
    required this.keywordHits,
  });

  final double total;
  final int phraseHits;
  final int keywordHits;
}

class _ScoredRead {
  const _ScoredRead({required this.read, required this.score});

  final InterpretationRead read;
  final double score;
}

class _DeepContent {
  const _DeepContent({
    required this.mightMean,
    required this.confirm,
    required this.contradict,
    required this.nextPrompt,
    required this.evidenceUsed,
  });

  final String mightMean;
  final String confirm;
  final String contradict;
  final String nextPrompt;
  final String evidenceUsed;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
