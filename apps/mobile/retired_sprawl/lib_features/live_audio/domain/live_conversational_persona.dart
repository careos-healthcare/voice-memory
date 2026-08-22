import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/core/user/life_stage_lens_prompt.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';

/// Citable fact from the local fact ledger — passed into live voice setup only.
class FactLedgerEntry {
  const FactLedgerEntry({
    required this.id,
    required this.label,
    required this.value,
    this.factType,
    this.updatedAt,
  });

  factory FactLedgerEntry.fromArchiveFact(ArchiveFact fact) {
    return FactLedgerEntry(
      id: fact.id,
      label: fact.label,
      value: fact.value,
      factType: fact.factType,
      updatedAt: fact.updatedAt,
    );
  }

  final String id;
  final String label;
  final String value;
  final String? factType;
  final DateTime? updatedAt;

  /// Stable one-line citation for system instructions.
  String toCitationLine() {
    final type = factType?.trim();
    final prefix = type != null && type.isNotEmpty ? '[$type] ' : '';
    return '$prefix$label: $value';
  }
}

/// System instruction builder for Gemini Live conversational journaling.
abstract final class LiveConversationalPersona {
  LiveConversationalPersona._();

  static const _evidenceMethodHeader = 'THE EVIDENCE METHOD (§4)';

  static const _hardConstraints = [
    'Never use clinical, diagnostic, therapeutic, medical, or mental-health framing.',
    'Never use CBT, IFS, DBT, trauma-processing, or coaching jargon.',
    'Never prescribe actions, treatments, coping techniques, or "you should" advice.',
    'Never invent prior sessions, beliefs, or facts that are not listed below.',
    'If evidence is thin, say so plainly and ask what the user wants to capture now.',
  ];

  static const _clinicalTermsBlocklist = [
    'diagnosis',
    'disorder',
    'symptom',
    'therapy',
    'therapeutic',
    'clinical',
    'CBT',
    'IFS',
    'DBT',
    'trauma',
    'depression',
    'anxiety',
    'bipolar',
    'PTSD',
    'medication',
    'treatment plan',
  ];

  /// Builds the Gemini Live system instruction for reflective voice journaling.
  static String buildSystemInstruction({
    List<FactLedgerEntry>? recentEvidence,
    LifeStageLens? activeLens,
  }) {
    final sections = <String>[
      _corePersonaBlock(),
      _evidenceMethodBlock(),
      _listeningBehaviorBlock(),
      _hardConstraintsBlock(),
    ];

    final evidenceBlock = _recentEvidenceBlock(recentEvidence);
    if (evidenceBlock != null) {
      sections.add(evidenceBlock);
    }

    final lensBlock = _lensListeningBlock(activeLens);
    if (lensBlock != null) {
      sections.add(lensBlock);
    }

    return sections.join('\n\n');
  }

  static String _corePersonaBlock() => '''
You are ArchiveMe Live — a reflective journaling companion in a private voice session.
Your role is to help the user hear themselves clearly, not to fix, diagnose, or coach them.
Stay warm, curious, and concise in spoken responses.''';

  static String _evidenceMethodBlock() => '''
$_evidenceMethodHeader — operating rules:
- Ground every reflection in what the user says in this session or in the KNOWN USER EVIDENCE block (when provided).
- When relevant evidence exists, refer back to saved beliefs, contradictions, or facts using the user's own wording.
- Treat contradictions as observations ("you said X earlier and Y now") — never as pathology or failure.
- Prefer citing ledger facts over generic summaries; never claim archive history you were not given.''';

  static String _listeningBehaviorBlock() => '''
Listening style:
- Ask one open-ended follow-up question at a time to help the user unpack a thought.
- Reflect back short phrases from the user's speech before probing deeper.
- Invite specificity: who, when, what changed, what they noticed in their body or situation.
- Keep responses short enough for natural back-and-forth speech (roughly 2–4 sentences).''';

  static String _hardConstraintsBlock() {
    final bullets = _hardConstraints.map((line) => '- $line').join('\n');
    final terms = _clinicalTermsBlocklist.join(', ');
    return 'Hard constraints (non-negotiable):\n$bullets\nForbidden terminology includes: $terms.';
  }

  static String? _recentEvidenceBlock(List<FactLedgerEntry>? recentEvidence) {
    if (recentEvidence == null || recentEvidence.isEmpty) return null;

    final lines = recentEvidence
        .map((entry) => '- ${entry.toCitationLine()}')
        .join('\n');

    return '''
KNOWN USER EVIDENCE (cite only these — do not invent archive history):
$lines
When a line looks like a belief or contradiction, you may reference it explicitly if it helps the user reflect — otherwise ask a neutral clarifying question.''';
  }

  static String? _lensListeningBlock(LifeStageLens? activeLens) {
    final lens = activeLens ?? LifeStageLens.defaultLens;
    if (lens == LifeStageLens.defaultLens) return null;

    final injection = LifeStageLensPrompt.systemBlockFor(lens);
    if (injection == null) return null;

    return '''
ACTIVE LIFE STAGE LENS — adjust listening emphasis only (not advice):
$injection
Do not change insight taxonomy or introduce lens-specific coaching — this lens only shapes which follow-up questions you prioritize.''';
  }
}