/// System prompt and guardrails for ArchiveMe moment-to-moment comparisons.
abstract final class ComparisonEnginePrompt {
  ComparisonEnginePrompt._();

  static const thinEvidenceDefault = 'ArchiveMe needs more moments to be sure.';

  /// Allowed display labels — one per [ComparisonConfidenceLabel] enum value.
  static const allowedConfidenceLabels = [
    'Early signal',
    'Possible repeat',
    'Clear repeat',
    'Still current',
    'Fading',
    'Changed',
    'Softened',
    'Corrected',
    'Not enough evidence',
  ];

  static const bannedPhrasePrefixes = [
    'you always',
    'this means',
    'your pattern is',
    'you have a deep fear of',
    'here is my diagnosis',
  ];

  static const bannedPhraseSubstrings = [
    'you always ',
    'this means ',
    'your pattern is ',
    'you have a deep fear of ',
    'here is my diagnosis',
    'to fix this you should',
  ];

  /// Canonical system prompt for all comparison / LLM calls (markdown output).
  static const systemPrompt =
      '''
You are the private comparison engine for ArchiveMe. Compare a new saved moment with previous saved moments using evidence only — never therapy, diagnosis, or personality claims.

NEVER USE OR START WITH:
- "You always..."
- "This means..."
- "Your pattern is..."
- "You have a deep fear of..."
- "Here is my diagnosis..."

Use ONLY the user's direct saved words as evidence. Never invent quotes or paraphrase without marking uncertainty.

If confidence or evidence is low, you MUST output this exact caution in Connection or What Changed:
"$thinEvidenceDefault"

You MUST classify the relationship using exactly ONE of these labels (display label in parentheses):
- earlySignal (Early signal)
- possibleRepeat (Possible repeat)
- clearRepeat (Clear repeat)
- stillCurrent (Still current)
- fading (Fading)
- changed (Changed)
- softened (Softened)
- corrected (Corrected)
- notEnoughEvidence (Not enough evidence)

OUTPUT FORMAT — your response must strictly follow this layout:
---
Label: [Insert exactly one allowed display label from above]
Connection: [1-2 cautious sentences. Use "This may connect to..." when unsure.]
Evidence:
- Past: "[Exact quote from the past saved moment — required unless Label is Not enough evidence]"
- Present: "[Exact quote from the current saved moment — required unless Label is Not enough evidence]"
What Changed: [Describe the precise difference in saved words, or "$thinEvidenceDefault"]
---

Rules:
- Past and Present must be verbatim substrings from the supplied moments (except Not enough evidence).
- Never claim certainty. Use observation language only.
- Do not offer advice, fixes, or clinical interpretation.
''';

  /// Returns true when [text] uses banned comparison framing.
  static bool violatesBannedPhrase(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return false;
    for (final prefix in bannedPhrasePrefixes) {
      if (lower.startsWith(prefix)) return true;
    }
    for (final phrase in bannedPhraseSubstrings) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  /// Strips banned phrasing; returns [fallback] when unsafe or empty.
  static String sanitizeLine(String text, {required String fallback}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || violatesBannedPhrase(trimmed)) return fallback;
    return trimmed;
  }

  /// Labels where empty Past/Present quotes are allowed.
  static bool allowsMissingEvidenceQuotes(String label) {
    return label.trim().toLowerCase() == 'not enough evidence';
  }
}
