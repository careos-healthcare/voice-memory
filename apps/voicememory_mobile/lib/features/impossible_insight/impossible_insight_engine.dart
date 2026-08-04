import '../../models/journal_entry.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';
import 'impossible_insight_gates.dart';
import 'impossible_insight_models.dart';

/// Conservative, deterministic detectors for unusually specific early insights.
///
/// This engine reads canonical transcripts only. It performs no persistence and
/// returns null whenever the complete conclusion cannot pass the shared gate.
class ImpossibleInsightEngine {
  const ImpossibleInsightEngine();

  ImpossibleInsight? build(List<JournalEntry> entries) {
    final eligible = ImpossibleInsightGates.eligible(entries);
    if (eligible.isEmpty) return null;
    final candidate =
        _exactRecurringPhrase(eligible) ??
        _repeatedSequence(eligible) ??
        _narrowCorrelation(eligible) ??
        _reversal(eligible) ??
        _microHabit(eligible);
    if (candidate == null ||
        !ImpossibleInsightGates.hasQuestionForm(
          candidate.nextEvidenceQuestion,
        )) {
      return null;
    }

    final conclusion = ExplainableConclusion(
      id: 'impossible_${candidate.kind.name}_${eligible.map((e) => e.id).join("_")}',
      statement: candidate.statement,
      confidence: candidate.confidence,
      reasoning: [
        'The engine compared ${eligible.length} eligible recordings.',
        'It retained only exact evidence matching this ${candidate.kind.name} pattern.',
      ],
      uncertaintyNote: candidate.uncertainty,
      evidence: candidate.evidence,
      alternatives: [
        ExplainableAlternative(
          statement: candidate.alternative,
          rationale: candidate.alternativeRationale,
          confidence: (candidate.confidence - 24).clamp(20, 65),
        ),
      ],
      provenance: ExplainableConclusionProvenance(
        source: 'deterministic',
        generatedAt: eligible.last.createdAt,
        schemaVersion: ExplainableConclusion.schemaVersion,
        sourceRevision: 'impossible_insight_v1:${candidate.kind.name}',
      ),
    );
    final canonical = {
      for (final entry in eligible) entry.id: entry.transcript,
    };
    final validated = ExplainableConclusionRenderGate.visible(
      conclusion,
      canonicalTranscripts: canonical,
    );
    if (validated == null) return null;
    if (_isMultiEntry(candidate.kind) &&
        candidate.evidence.map((e) => e.entryId).toSet().length < 2) {
      return null;
    }
    return ImpossibleInsight(
      kind: candidate.kind,
      conclusion: validated,
      nextEvidenceQuestion: candidate.nextEvidenceQuestion,
    );
  }

  bool _isMultiEntry(ImpossibleInsightKind kind) =>
      kind != ImpossibleInsightKind.explicitMicroHabit;

  ImpossibleInsightCandidate? _exactRecurringPhrase(
    List<JournalEntry> entries,
  ) {
    if (entries.length < 2) return null;
    final occurrences = <String, List<_PhraseOccurrence>>{};
    for (final entry in entries) {
      final words = RegExp(
        r"[^\s.,!?;:()\[\]{}]+",
        unicode: true,
      ).allMatches(entry.transcript).toList();
      for (var size = 8; size >= 3; size--) {
        for (var i = 0; i + size <= words.length; i++) {
          final start = words[i].start;
          final end = words[i + size - 1].end;
          final quote = entry.transcript.substring(start, end);
          if (!ImpossibleInsightGates.isConcretePhrase(quote)) continue;
          final key = quote
              .toLowerCase()
              .replaceAll('’', "'")
              .replaceAll(RegExp(r'\s+'), ' ');
          occurrences
              .putIfAbsent(key, () => [])
              .add(_PhraseOccurrence(entry, quote, start, end));
        }
      }
    }
    final repeated =
        occurrences.entries
            .where(
              (item) => item.value.map((o) => o.entry.id).toSet().length >= 2,
            )
            .toList()
          ..sort((a, b) {
            final words = b.key
                .split(' ')
                .length
                .compareTo(a.key.split(' ').length);
            return words != 0 ? words : a.key.compareTo(b.key);
          });
    if (repeated.isEmpty) return null;
    final selected = _distinctOccurrences(
      repeated.first.value,
    ).take(3).toList();
    final phrase = selected.first.quote;
    return ImpossibleInsightCandidate(
      kind: ImpossibleInsightKind.exactRecurringPhrase,
      statement: 'The exact wording “$phrase” recurred across saved moments.',
      confidence: selected.length >= 3 ? 92 : 84,
      uncertainty:
          'Repeated wording is clear, but the recordings do not establish why it recurred.',
      evidence: selected.map(_citation).toList(),
      alternative: 'The wording may be a familiar way of telling the story',
      alternativeRationale:
          'A repeated phrase can reflect speaking style rather than a repeated behavior.',
      nextEvidenceQuestion:
          'When does “$phrase” show up again, and what happens immediately before it?',
    );
  }

  ImpossibleInsightCandidate? _repeatedSequence(List<JournalEntry> entries) {
    if (entries.length < 2) return null;
    final sequences = entries.map(_sequenceIn).whereType<_Sequence>().toList();
    for (final first in sequences) {
      if (first.cost == null) continue;
      final matches = sequences
          .where(
            (item) =>
                item.action == first.action &&
                item.cost == first.cost &&
                item.entry.id != first.entry.id,
          )
          .toList();
      if (matches.isEmpty) continue;
      final selected = [first, matches.first];
      return ImpossibleInsightCandidate(
        kind: ImpossibleInsightKind.repeatedTriggerActionCost,
        statement:
            'In two moments, a trigger came before ${first.action.label}, followed by ${first.cost!.label}.',
        confidence: 82,
        uncertainty:
            'The order repeats in these recordings, but that does not show that one step caused the next.',
        evidence: selected
            .map((item) => _spanCitation(item.entry, item.span))
            .toList(),
        alternative: 'The similar order may be incidental',
        alternativeRationale:
            'Two moments can share an order because they were described similarly, not because it is a stable sequence.',
        nextEvidenceQuestion:
            'When this trigger appears next, what action and cost follow, if any?',
      );
    }
    return null;
  }

  ImpossibleInsightCandidate? _microHabit(List<JournalEntry> entries) {
    for (final entry in entries.reversed) {
      for (final span in _sentences(entry.transcript)) {
        final lower = span.text.toLowerCase();
        final trigger = RegExp(
          r'\b(?:whenever|every time|each time|when)\b',
        ).firstMatch(lower);
        final action = _actions.entries
            .where((item) => item.value.hasMatch(lower))
            .firstOrNull;
        if (trigger == null || action == null) continue;
        final actionMatch = action.value.firstMatch(lower)!;
        if (actionMatch.start <= trigger.end ||
            !RegExp(
              r'\b(?:i|my)\b',
            ).hasMatch(lower.substring(trigger.end, actionMatch.end))) {
          continue;
        }
        return ImpossibleInsightCandidate(
          kind: ImpossibleInsightKind.explicitMicroHabit,
          statement:
              'This moment explicitly describes a micro-habit: a trigger followed by ${action.key.label}.',
          confidence: 68,
          uncertainty:
              'This is explicit in one recording only, so it may describe a one-off moment rather than a recurring habit.',
          evidence: [_spanCitation(entry, span)],
          alternative: 'This may be a one-time response',
          alternativeRationale:
              'One strongly worded entry cannot show that the same response happens repeatedly.',
          nextEvidenceQuestion:
              'When the same trigger happens next, do you ${action.key.questionLabel} again?',
        );
      }
    }
    return null;
  }

  ImpossibleInsightCandidate? _reversal(List<JournalEntry> entries) {
    if (entries.length < 2) return null;
    for (final tension in _tensions) {
      _SentenceHit? intention;
      _SentenceHit? reversal;
      for (final entry in entries) {
        for (final span in _sentences(entry.transcript)) {
          final lower = span.text.toLowerCase();
          if (intention == null && tension.intention.hasMatch(lower)) {
            intention = _SentenceHit(entry, span);
          }
          if (reversal == null && tension.reversal.hasMatch(lower)) {
            reversal = _SentenceHit(entry, span);
          }
        }
      }
      if (intention == null ||
          reversal == null ||
          intention.entry.id == reversal.entry.id) {
        continue;
      }
      return ImpossibleInsightCandidate(
        kind: ImpossibleInsightKind.reversal,
        statement: tension.statement,
        confidence: 78,
        uncertainty:
            'These two moments contain a real tension, but they may involve different circumstances.',
        evidence: [
          _spanCitation(intention.entry, intention.span),
          _spanCitation(reversal.entry, reversal.span),
        ],
        alternative: 'The two choices may fit different constraints',
        alternativeRationale:
            'Opposite wording across separate moments does not prove an internal pattern.',
        nextEvidenceQuestion:
            'When this tension appears next, which side shows up in what you actually do?',
      );
    }
    return null;
  }

  ImpossibleInsightCandidate? _narrowCorrelation(List<JournalEntry> entries) {
    if (entries.length < 3) return null;
    final sequences = entries.map(_sequenceIn).whereType<_Sequence>().toList();
    for (final first in sequences) {
      final matches = sequences
          .where(
            (item) =>
                item.trigger == first.trigger && item.action == first.action,
          )
          .toList();
      if (matches.map((e) => e.entry.id).toSet().length < 3) continue;
      final selected = matches.take(5).toList();
      return ImpossibleInsightCandidate(
        kind: ImpossibleInsightKind.narrowSequenceCorrelation,
        statement:
            'Across ${selected.length} early moments, ${first.trigger.label} appeared before ${first.action.label}.',
        confidence: selected.length >= 4 ? 90 : 86,
        uncertainty:
            'This is a narrow ordering correlation in a small early sample, not evidence that the trigger causes the action.',
        evidence: selected
            .map((item) => _spanCitation(item.entry, item.span))
            .toList(),
        alternative: 'The ordering may come from how the moments were narrated',
        alternativeRationale:
            'People often describe context before action even when there is no recurring behavioral link.',
        nextEvidenceQuestion:
            'Does ${first.action.label} still follow ${first.trigger.label} in the next comparable moment?',
      );
    }
    return null;
  }

  _Sequence? _sequenceIn(JournalEntry entry) {
    for (final span in _sentences(entry.transcript)) {
      final lower = span.text.toLowerCase();
      final trigger = _triggers.entries
          .map((item) => (kind: item.key, match: item.value.firstMatch(lower)))
          .where((item) => item.match != null)
          .firstOrNull;
      final action = _actions.entries
          .map((item) => (kind: item.key, match: item.value.firstMatch(lower)))
          .where((item) => item.match != null)
          .firstOrNull;
      if (trigger == null ||
          action == null ||
          trigger.match!.start >= action.match!.start) {
        continue;
      }
      final cost = _costs.entries
          .map((item) => (kind: item.key, match: item.value.firstMatch(lower)))
          .where(
            (item) =>
                item.match != null && item.match!.start > action.match!.start,
          )
          .firstOrNull;
      return _Sequence(
        entry: entry,
        span: span,
        trigger: trigger.kind,
        action: action.kind,
        cost: cost?.kind,
      );
    }
    return null;
  }

  List<_TextSpan> _sentences(String text) {
    final out = <_TextSpan>[];
    for (final match in RegExp(r'[^.!?\n]+[.!?]?').allMatches(text)) {
      final raw = match.group(0)!;
      final leading = raw.length - raw.trimLeft().length;
      final trimmed = raw.trim();
      if (trimmed.length < 12) continue;
      out.add(
        _TextSpan(
          trimmed,
          match.start + leading,
          match.start + leading + trimmed.length,
        ),
      );
    }
    return out;
  }

  TranscriptEvidenceCitation _citation(_PhraseOccurrence occurrence) =>
      TranscriptEvidenceCitation(
        entryId: occurrence.entry.id,
        quote: occurrence.quote,
        startUtf16: occurrence.start,
        endUtf16: occurrence.end,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: occurrence.entry.createdAt,
        sourceType: occurrence.entry.localAudioReference == null
            ? EvidenceSourceType.text
            : EvidenceSourceType.voice,
      );

  TranscriptEvidenceCitation _spanCitation(
    JournalEntry entry,
    _TextSpan span,
  ) => TranscriptEvidenceCitation(
    entryId: entry.id,
    quote: span.text,
    startUtf16: span.start,
    endUtf16: span.end,
    role: TranscriptEvidenceRole.supporting,
    sourceCapturedAt: entry.createdAt,
    sourceType: entry.localAudioReference == null
        ? EvidenceSourceType.text
        : EvidenceSourceType.voice,
  );

  Iterable<_PhraseOccurrence> _distinctOccurrences(
    List<_PhraseOccurrence> values,
  ) sync* {
    final ids = <String>{};
    for (final value in values) {
      if (ids.add(value.entry.id)) yield value;
    }
  }

  static final _triggers = <_Trigger, RegExp>{
    _Trigger.request: RegExp(
      r'\b(?:when|after|whenever).{0,40}\b(?:asked|request|message|email|notification)\b',
    ),
    _Trigger.pressure: RegExp(
      r'\b(?:when|after|whenever).{0,40}\b(?:deadline|pressure|urgent)\b',
    ),
    _Trigger.uncertainty: RegExp(
      r'\b(?:when|after|whenever).{0,40}\b(?:uncertain|unsure|didn.t know)\b',
    ),
  };

  static final _actions = <_Action, RegExp>{
    _Action.sayingYes: RegExp(r'\b(?:i\s+)?(?:said|say|saying)\s+yes\b'),
    _Action.checking: RegExp(r'\b(?:i\s+)?(?:checked|check|checking)\b'),
    _Action.keepingWorking: RegExp(
      r'\b(?:i\s+)?(?:kept|keep)\s+(?:on\s+)?working\b',
    ),
    _Action.stayingQuiet: RegExp(r'\b(?:i\s+)?(?:stayed|stay|kept)\s+quiet\b'),
    _Action.avoiding: RegExp(r'\b(?:i\s+)?(?:avoided|avoid|put off)\b'),
  };

  static final _costs = <_Cost, RegExp>{
    _Cost.exhaustion: RegExp(
      r'\b(?:exhausted|drained|wiped out|lost sleep|tired)\b',
    ),
    _Cost.pressure: RegExp(
      r'\b(?:pressure|stressed|stress|overwhelmed|anxious)\b',
    ),
    _Cost.regret: RegExp(
      r'\b(?:regretted|regret|resented|resentment|felt guilty)\b',
    ),
  };

  static final _tensions = <_Tension>[
    _Tension(
      intention: RegExp(
        r'\b(?:want|wanted|need|needed|planned|tried)\b.{0,35}\b(?:rest|stop)\b',
      ),
      reversal: RegExp(
        r'\b(?:kept working|worked anyway|took on more|said yes anyway)\b',
      ),
      statement:
          'One moment names wanting rest, while another records continuing or taking on more.',
    ),
    _Tension(
      intention: RegExp(
        r'\b(?:want|wanted|tried|needed)\b.{0,35}\b(?:say no|decline|set a boundary)\b',
      ),
      reversal: RegExp(r'\b(?:said yes|agreed anyway|took it on)\b'),
      statement:
          'One moment names wanting to decline, while another records agreeing.',
    ),
    _Tension(
      intention: RegExp(
        r'\b(?:want|wanted|tried|needed)\b.{0,35}\b(?:speak|say something|be direct)\b',
      ),
      reversal: RegExp(
        r'\b(?:stayed quiet|kept quiet|didn.t say|avoided the conversation)\b',
      ),
      statement:
          'One moment names wanting to speak directly, while another records staying quiet.',
    ),
  ];
}

class _PhraseOccurrence {
  const _PhraseOccurrence(this.entry, this.quote, this.start, this.end);
  final JournalEntry entry;
  final String quote;
  final int start;
  final int end;
}

class _TextSpan {
  const _TextSpan(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

class _Sequence {
  const _Sequence({
    required this.entry,
    required this.span,
    required this.trigger,
    required this.action,
    required this.cost,
  });
  final JournalEntry entry;
  final _TextSpan span;
  final _Trigger trigger;
  final _Action action;
  final _Cost? cost;
}

class _SentenceHit {
  const _SentenceHit(this.entry, this.span);
  final JournalEntry entry;
  final _TextSpan span;
}

enum _Trigger {
  request('a request or message'),
  pressure('urgent pressure'),
  uncertainty('uncertainty');

  const _Trigger(this.label);
  final String label;
}

enum _Action {
  sayingYes('saying yes', 'say yes'),
  checking('checking', 'check'),
  keepingWorking('continuing to work', 'keep working'),
  stayingQuiet('staying quiet', 'stay quiet'),
  avoiding('avoiding the situation', 'avoid it');

  const _Action(this.label, this.questionLabel);
  final String label;
  final String questionLabel;
}

enum _Cost {
  exhaustion('exhaustion'),
  pressure('pressure'),
  regret('regret');

  const _Cost(this.label);
  final String label;
}

class _Tension {
  const _Tension({
    required this.intention,
    required this.reversal,
    required this.statement,
  });
  final RegExp intention;
  final RegExp reversal;
  final String statement;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
