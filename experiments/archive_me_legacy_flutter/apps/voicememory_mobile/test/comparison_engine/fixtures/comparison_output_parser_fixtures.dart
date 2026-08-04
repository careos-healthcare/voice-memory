import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';

final class ComparisonParserFixture {
  const ComparisonParserFixture({
    required this.name,
    required this.input,
    this.expectedState = PatternState.notEnoughEvidence,
    this.expectedConnection = 'A repeating thread may be forming.',
    this.expectedPast = '',
    this.expectedCurrent = '',
    this.expectedWhatChanged = 'ArchiveMe needs more moments to be sure.',
  });

  final String name;
  final String input;
  final PatternState expectedState;
  final String expectedConnection;
  final String expectedPast;
  final String expectedCurrent;
  final String expectedWhatChanged;
}

final veryLongComparisonText = List<String>.filled(
  1500,
  'A detailed but bounded observation.',
).join(' ');

final comparisonOutputParserFixtures = <ComparisonParserFixture>[
  const ComparisonParserFixture(
    name: 'missing colons',
    input: '''
Label Clear Repeat
Connection A familiar pressure returned.
Evidence
- Past "I rushed before."
- Present "I rushed today."
What Changed The setting is different.
''',
    expectedState: PatternState.clearRepeat,
    expectedConnection: 'A familiar pressure returned.',
    expectedPast: 'I rushed before.',
    expectedCurrent: 'I rushed today.',
    expectedWhatChanged: 'The setting is different.',
  ),
  const ComparisonParserFixture(
    name: 'missing label',
    input: '''
Connection: The same choice appeared twice.
Evidence:
- Past: "I agreed last week."
- Present: "I agreed today."
What Changed: The response was quicker.
''',
    expectedConnection: 'The same choice appeared twice.',
    expectedPast: 'I agreed last week.',
    expectedCurrent: 'I agreed today.',
    expectedWhatChanged: 'The response was quicker.',
  ),
  const ComparisonParserFixture(
    name: 'extra whitespace',
    input: '''
     Label   :    Softened
 Connection :   The reaction carries less tension.   
 Evidence :
   - Past :   "I felt trapped."   
   - Present :   "I can pause."   
 What Changed :   More room appeared.   
''',
    expectedState: PatternState.softened,
    expectedConnection: 'The reaction carries less tension.',
    expectedPast: 'I felt trapped.',
    expectedCurrent: 'I can pause.',
    expectedWhatChanged: 'More room appeared.',
  ),
  const ComparisonParserFixture(
    name: 'markdown formatting',
    input: '''
## **Label:** **Changed**
### **Connection:** **The response shifted.**
## **Evidence:**
- **Past:** _"I cannot stop."_
- **Present:** _"I chose to pause."_
## **What Changed:** **Choice replaced urgency.**
''',
    expectedState: PatternState.changed,
    expectedConnection: 'The response shifted.',
    expectedPast: 'I cannot stop.',
    expectedCurrent: 'I chose to pause.',
    expectedWhatChanged: 'Choice replaced urgency.',
  ),
  const ComparisonParserFixture(
    name: 'triple backticks',
    input: '''
```markdown
Label: Early signal
Connection: A new thread may be starting.
Evidence:
- Past: "The first mention."
- Present: "The second mention."
What Changed: It appeared twice.
```
''',
    expectedState: PatternState.earlySignal,
    expectedConnection: 'A new thread may be starting.',
    expectedPast: 'The first mention.',
    expectedCurrent: 'The second mention.',
    expectedWhatChanged: 'It appeared twice.',
  ),
  const ComparisonParserFixture(
    name: 'bullet lists',
    input: '''
* Label: Possible repeat
* Connection: A repeated boundary concern.
* Evidence:
  * Past: "I needed space."
  + Current: "I asked for space."
* What Changed: The need became explicit.
''',
    expectedState: PatternState.possibleRepeat,
    expectedConnection: 'A repeated boundary concern.',
    expectedPast: 'I needed space.',
    expectedCurrent: 'I asked for space.',
    expectedWhatChanged: 'The need became explicit.',
  ),
  const ComparisonParserFixture(
    name: 'numbered lists',
    input: '''
1. Label: Still current
2. Connection: The concern remains active.
3. Evidence:
1) Past: "I worried then."
2) Present: "I worry now."
4. What Changed: The language stayed similar.
''',
    expectedState: PatternState.stillCurrent,
    expectedConnection: 'The concern remains active.',
    expectedPast: 'I worried then.',
    expectedCurrent: 'I worry now.',
    expectedWhatChanged: 'The language stayed similar.',
  ),
  const ComparisonParserFixture(
    name: 'multiline sections',
    input: '''
Label: Corrected
Connection:
The same assumption appeared,
but it was questioned this time.
Evidence:
- Past: "I assumed the worst
without asking."
- Present: "I checked first."
What Changed:
The newer moment includes
a direct reality check.
''',
    expectedState: PatternState.corrected,
    expectedConnection:
        'The same assumption appeared, but it was questioned this time.',
    expectedPast: 'I assumed the worst without asking.',
    expectedCurrent: 'I checked first.',
    expectedWhatChanged: 'The newer moment includes a direct reality check.',
  ),
  const ComparisonParserFixture(
    name: 'reordered sections',
    input: '''
What Changed: The response became calmer.
Evidence:
- Present: "I waited."
- Past: "I reacted."
Connection: The trigger is similar.
Label: Softened
''',
    expectedState: PatternState.softened,
    expectedConnection: 'The trigger is similar.',
    expectedPast: 'I reacted.',
    expectedCurrent: 'I waited.',
    expectedWhatChanged: 'The response became calmer.',
  ),
  const ComparisonParserFixture(
    name: 'unexpected headings',
    input: '''
Label: Changed
Connection: A valid connection.
Model Notes: This must not enter the connection.
Unstructured commentary that must also stay out.
Evidence:
- Past: "Before."
- Present: "After."
What Changed: A valid change.
''',
    expectedState: PatternState.changed,
    expectedConnection: 'A valid connection.',
    expectedPast: 'Before.',
    expectedCurrent: 'After.',
    expectedWhatChanged: 'A valid change.',
  ),
  const ComparisonParserFixture(
    name: 'duplicated headings',
    input: '''
Label: Clear repeat
Label: unsupported certainty
Connection: First connection.
Connection:
Connection: Final valid connection.
Evidence:
- Past: "First past."
- Past:
- Present: "Current evidence."
What Changed: Valid analysis.
What Changed:
''',
    expectedState: PatternState.clearRepeat,
    expectedConnection: 'Final valid connection.',
    expectedPast: 'First past.',
    expectedCurrent: 'Current evidence.',
    expectedWhatChanged: 'Valid analysis.',
  ),
  const ComparisonParserFixture(
    name: 'partial response',
    input: '''
Label: Possible repeat
Connection: A partial but useful connection.
''',
    expectedState: PatternState.possibleRepeat,
    expectedConnection: 'A partial but useful connection.',
  ),
  const ComparisonParserFixture(
    name: 'empty sections',
    input: '''
Label:
Connection:
Evidence:
- Past:
- Present:
What Changed:
''',
  ),
  ComparisonParserFixture(
    name: 'very long text',
    input:
        '''
Label: Early signal
Connection: $veryLongComparisonText
What Changed: Long output remained parseable.
''',
    expectedState: PatternState.earlySignal,
    expectedConnection: veryLongComparisonText,
    expectedWhatChanged: 'Long output remained parseable.',
  ),
  const ComparisonParserFixture(
    name: 'unicode characters',
    input: '''
Label: Changed
Connection: Café conversations shifted from “mañana” to “今日”.
Evidence:
- Past: “J'étais inquiet.”
- Present: “Estoy más tranquilo.”
What Changed: Αλλαγή became visible.
''',
    expectedState: PatternState.changed,
    expectedConnection: 'Café conversations shifted from “mañana” to “今日”.',
    expectedPast: "J'étais inquiet.",
    expectedCurrent: 'Estoy más tranquilo.',
    expectedWhatChanged: 'Αλλαγή became visible.',
  ),
  const ComparisonParserFixture(
    name: 'emojis',
    input: '''
Label: Softened
Connection: Stress 😰 shifted toward relief 🌤️.
Evidence:
- Past: "Everything felt heavy 😞."
- Present: "I can breathe now 😊."
What Changed: The emotional signal softened 💛.
''',
    expectedState: PatternState.softened,
    expectedConnection: 'Stress 😰 shifted toward relief 🌤️.',
    expectedPast: 'Everything felt heavy 😞.',
    expectedCurrent: 'I can breathe now 😊.',
    expectedWhatChanged: 'The emotional signal softened 💛.',
  ),
  const ComparisonParserFixture(
    name: 'trailing markdown',
    input: '''
Label: Fading
Connection: The old concern appears less often.
Evidence:
- Past: "It occupied every day."
- Present: "It crossed my mind once."
What Changed: Frequency decreased.
---
***
```
''',
    expectedState: PatternState.fading,
    expectedConnection: 'The old concern appears less often.',
    expectedPast: 'It occupied every day.',
    expectedCurrent: 'It crossed my mind once.',
    expectedWhatChanged: 'Frequency decreased.',
  ),
  const ComparisonParserFixture(
    name: 'malformed markdown',
    input: '''
**Label: Corrected
__Connection: A correction appeared.__
Evidence:**
- **Past: "I knew the answer."
- Present: "I checked the answer."__
**What Changed: Verification replaced certainty.
''',
    expectedState: PatternState.corrected,
    expectedConnection: 'A correction appeared.',
    expectedPast: 'I knew the answer.',
    expectedCurrent: 'I checked the answer.',
    expectedWhatChanged: 'Verification replaced certainty.',
  ),
  const ComparisonParserFixture(
    name: 'blank lines',
    input: '''


Label: Early signal

Connection: A sparse response.

Evidence:

- Past: "One."

- Present: "Two."

What Changed: Another mention appeared.

''',
    expectedState: PatternState.earlySignal,
    expectedConnection: 'A sparse response.',
    expectedPast: 'One.',
    expectedCurrent: 'Two.',
    expectedWhatChanged: 'Another mention appeared.',
  ),
  const ComparisonParserFixture(
    name: 'mixed line endings',
    input:
        'Label: Changed\r\nConnection: Mixed endings work.\rEvidence:\n'
        '- Past: "Old."\r\n- Present: "New."\r'
        'What Changed: Transport formatting differed.',
    expectedState: PatternState.changed,
    expectedConnection: 'Mixed endings work.',
    expectedPast: 'Old.',
    expectedCurrent: 'New.',
    expectedWhatChanged: 'Transport formatting differed.',
  ),
  const ComparisonParserFixture(
    name: 'incomplete response',
    input: '''
Label: Clear repeat
Connection: The response ended unexpectedly
Evidence:
- Past: "An opening quote without a close
- Present:
What Changed:
''',
    expectedState: PatternState.clearRepeat,
    expectedConnection: 'The response ended unexpectedly',
    expectedPast: 'An opening quote without a close',
  ),
];
