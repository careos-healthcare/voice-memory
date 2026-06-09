import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

enum ArchiveQualityPersona {
  founder,
  burnedOutEmployee,
  anxiousOverthinker,
  relationshipFocused,
  fitnessFocused,
}

/// Synthetic reflections with deliberate arcs (emerging / fading / contradictions).
List<JournalEntry> buildPersonaArchive(
  ArchiveQualityPersona persona, {
  required int count,
}) {
  final full = _buildFull(persona);
  if (count >= full.length) return full;
  return full.sublist(full.length - count);
}

List<JournalEntry> _buildFull(ArchiveQualityPersona persona) {
  switch (persona) {
    case ArchiveQualityPersona.founder:
      return _founderEntries();
    case ArchiveQualityPersona.burnedOutEmployee:
      return _burnedOutEntries();
    case ArchiveQualityPersona.anxiousOverthinker:
      return _anxiousEntries();
    case ArchiveQualityPersona.relationshipFocused:
      return _relationshipEntries();
    case ArchiveQualityPersona.fitnessFocused:
      return _fitnessEntries();
  }
}

JournalEntry _e({
  required String id,
  required DateTime at,
  required String transcript,
  required String observation,
  List<String> themes = const [],
  String tensionOrContradiction = '',
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 45,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 3,
      recurringThemes: themes,
      exactLanguagePattern: transcript.length > 40
          ? transcript.substring(0, 40)
          : transcript,
      concreteObservation: observation,
      repeatedSignal: themes.isNotEmpty ? themes.first : '',
      tensionOrContradiction:
          tensionOrContradiction.isEmpty ? null : tensionOrContradiction,
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

DateTime _month(int year, int month, int day) =>
    DateTime.utc(year, month, day, 14);

List<JournalEntry> _founderEntries() {
  final out = <JournalEntry>[];
  var i = 0;
  void add(
    DateTime at,
    String t,
    String obs, {
    List<String> themes = const ['career', 'money'],
    String tensionOrContradiction = '',
  }) {
    out.add(
      _e(
        id: 'f${i++}',
        at: at,
        transcript: t,
        observation: obs,
        themes: themes,
        tensionOrContradiction: tensionOrContradiction,
      ),
    );
  }

  // Fading: runway-before-hiring (Jan–Mar 2024)
  for (var m = 1; m <= 3; m++) {
    for (var w = 0; w < 8; w++) {
      add(
        _month(2024, m, 2 + w * 3),
        'I keep telling myself we need more runway before hiring even though engineers are drowning in work.',
        'I need more runway before hiring anyone new on the team.',
        themes: const ['money', 'career'],
      );
    }
  }

  // Emerging: cofounder difficult conversations (grows Apr 2024 → May 2025)
  for (var month = 4; month <= 12; month++) {
    final reps = month < 7 ? 2 : (month < 10 ? 4 : 7);
    for (var r = 0; r < reps; r++) {
      add(
        _month(2024, month, 5 + r),
        'I avoid difficult conversations with my cofounder when equity and product direction feel tense.',
        'I avoid difficult conversations with my cofounder when stakes feel personal.',
        themes: const ['career', 'avoidance'],
      );
    }
  }
  for (var month = 1; month <= 5; month++) {
    for (var r = 0; r < 9; r++) {
      add(
        _month(2025, month, 3 + r),
        'I avoid difficult conversations with my cofounder when equity and product direction feel tense.',
        'I avoid difficult conversations with my cofounder when stakes feel personal.',
        themes: const ['career', 'avoidance'],
      );
    }
  }

  // Contradiction arc: gut trust → data paralysis
  add(
    _month(2024, 2, 10),
    'I trust my gut on product bets and move fast when customers pull us.',
    'I trust my gut on product decisions.',
    themes: const ['career', 'confidence'],
  );
  add(
    _month(2024, 9, 10),
    'I cannot ship without more data now — every product decision feels too risky to trust instinct.',
    'I need more data before every product decision and that slows us down.',
    themes: const ['career', 'confidence'],
    tensionOrContradiction: 'Earlier I trusted instinct; now I stall on data.',
  );

  // Counter-evidence (direct conversations)
  for (var k = 0; k < 6; k++) {
    add(
      _month(2025, 3, 8 + k),
      'Today I had a direct conversation with my cofounder about runway and we aligned on hiring one senior engineer.',
      'I had a direct conversation with my cofounder about hiring today.',
      themes: const ['career'],
    );
  }

  // Current dominant (last ~35 observations)
  for (var k = 0; k < 35; k++) {
    add(
      _month(2025, 4, 1 + (k % 20)),
      'I postpone hiring until runway feels secure even when the team is clearly overloaded and burning out.',
      'I postpone hiring until runway feels secure even when the team is overloaded.',
      themes: const ['money', 'career'],
    );
  }

  out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return out.take(200).toList();
}

List<JournalEntry> _burnedOutEntries() {
  final out = <JournalEntry>[];
  var i = 0;
  void add(
    DateTime at,
    String t,
    String obs, {
    List<String> themes = const ['career'],
    String tensionOrContradiction = '',
  }) {
    out.add(
      _e(
        id: 'b${i++}',
        at: at,
        transcript: t,
        observation: obs,
        themes: themes,
        tensionOrContradiction: tensionOrContradiction,
      ),
    );
  }

  // Fading ambition
  for (var m = 1; m <= 4; m++) {
    for (var r = 0; r < 6; r++) {
      add(
        _month(2024, m, 4 + r),
        'I want a promotion this year and I am pushing hard on visibility with my manager.',
        'I want a promotion and I am chasing visibility at work.',
        themes: const ['career', 'approval'],
      );
    }
  }

  // Emerging boundaries
  for (var m = 5; m <= 12; m++) {
    for (var r = 0; r < (m < 9 ? 3 : 6); r++) {
      add(
        _month(2024, m, 6 + r),
        'I am trying to set boundaries with my manager about after-hours messages and weekend pings.',
        'I am learning to set boundaries with my manager about after-hours work.',
        themes: const ['career', 'avoidance'],
      );
    }
  }

  // Contradiction: love team vs dread Slack
  add(
    _month(2024, 3, 12),
    'I genuinely love this team and the mission we are building together every day.',
    'I love this team and the mission we are on.',
    themes: const ['career', 'relationships'],
  );
  add(
    _month(2024, 10, 12),
    'I dread opening Slack on Monday morning and my chest tightens before standup.',
    'I dread opening Slack on Monday and standup fills me with dread.',
    themes: const ['career', 'health'],
    tensionOrContradiction: 'I said I love the team but Mondays feel unbearable.',
  );

  // Help others (blind spot trigger)
  for (var k = 0; k < 12; k++) {
    add(
      _month(2024, 6 + (k % 6), 10 + k),
      'I spent the evening helping a colleague debug their project instead of resting.',
      'I focus on helping others at work even when I am depleted.',
      themes: const ['relationships'],
    );
  }

  // Current: exhaustion
  for (var k = 0; k < 40; k++) {
    add(
      _month(2025, 2 + (k % 4), 2 + (k % 25)),
      'I feel exhausted before the workday starts and recovery weekends do not refill my energy at all.',
      'I feel exhausted before the workday starts and weekends do not refill me.',
      themes: const ['health', 'career'],
    );
  }

  out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return out.take(200).toList();
}

List<JournalEntry> _anxiousEntries() {
  final out = <JournalEntry>[];
  var i = 0;
  void add(
    DateTime at,
    String t,
    String obs, {
    List<String> themes = const ['confidence'],
    String tensionOrContradiction = '',
  }) {
    out.add(
      _e(
        id: 'a${i++}',
        at: at,
        transcript: t,
        observation: obs,
        themes: themes,
        tensionOrContradiction: tensionOrContradiction,
      ),
    );
  }

  // Fading: spontaneous action
  for (var m = 1; m <= 5; m++) {
    for (var r = 0; r < 5; r++) {
      add(
        _month(2024, m, 3 + r),
        'I used to make quick decisions and adjust later without replaying every outcome.',
        'I used to act without needing certainty first.',
        themes: const ['confidence'],
      );
    }
  }

  // Emerging: certainty-seeking
  for (var m = 4; m <= 12; m++) {
    for (var r = 0; r < (m < 8 ? 2 : 5); r++) {
      add(
        _month(2024, m, 8 + r),
        'I increasingly need certainty before acting and I rewrite plans until they feel foolproof.',
        'I increasingly seek certainty before acting on anything important.',
        themes: const ['confidence', 'avoidance'],
      );
    }
  }
  for (var m = 1; m <= 5; m++) {
    for (var r = 0; r < 8; r++) {
      add(
        _month(2025, m, 4 + r),
        'I increasingly need certainty before acting and I rewrite plans until they feel foolproof.',
        'I increasingly seek certainty before acting on anything important.',
        themes: const ['confidence', 'avoidance'],
      );
    }
  }

  add(
    _month(2024, 2, 15),
    'I am comfortable with ambiguity in conversations and I do not need closure same-day.',
    'I am comfortable with ambiguity and loose ends.',
    themes: const ['confidence'],
  );
  add(
    _month(2024, 11, 15),
    'I replay conversations until I feel certain about what someone meant and what I should do next.',
    'I replay conversations until I feel certain about what someone meant.',
    themes: const ['confidence'],
    tensionOrContradiction: 'Ambiguity used to be fine; now I need closure.',
  );

  for (var k = 0; k < 8; k++) {
    add(
      _month(2025, 2, 10 + k),
      'Yesterday I sent the email without over-editing and it felt relieving.',
      'I acted without over-editing and it felt relieving.',
      themes: const ['confidence'],
    );
  }

  for (var k = 0; k < 38; k++) {
    add(
      _month(2025, 3 + (k % 3), 2 + (k % 22)),
      'I replay conversations until I feel certain about what someone meant and what I should do next.',
      'I replay conversations until I feel certain about what someone meant.',
      themes: const ['confidence'],
    );
  }

  out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return out.take(200).toList();
}

List<JournalEntry> _relationshipEntries() {
  final out = <JournalEntry>[];
  var i = 0;
  void add(
    DateTime at,
    String t,
    String obs, {
    List<String> themes = const ['relationships'],
    String tensionOrContradiction = '',
  }) {
    out.add(
      _e(
        id: 'r${i++}',
        at: at,
        transcript: t,
        observation: obs,
        themes: themes,
        tensionOrContradiction: tensionOrContradiction,
      ),
    );
  }

  // Work noise (theme gap: relationships claimed rarely)
  for (var k = 0; k < 45; k++) {
    add(
      _month(2024 + (k ~/ 12), 1 + (k % 12), 5 + (k % 20)),
      'My manager expects faster delivery on the roadmap and I am behind on quarterly goals.',
      'Work delivery pressure dominates my week.',
      themes: const ['career'],
    );
  }

  // Relationship signal (moderate)
  for (var m = 1; m <= 12; m++) {
    for (var r = 0; r < 3; r++) {
      add(
        _month(2024, m, 10 + r),
        'Relationships matter most to me but I struggle to show up consistently for my partner.',
        'Relationships matter most to me but I struggle to show up for my partner.',
        themes: const ['relationships'],
      );
    }
  }

  // Emerging: avoidance of needs
  for (var m = 6; m <= 12; m++) {
    for (var r = 0; r < 5; r++) {
      add(
        _month(2024, m, 15 + r),
        'I avoid bringing up needs with my partner until resentment builds and we fight about small things.',
        'I avoid bringing up needs with my partner until resentment builds.',
        themes: const ['relationships', 'avoidance'],
      );
    }
  }
  for (var m = 1; m <= 5; m++) {
    for (var r = 0; r < 7; r++) {
      add(
        _month(2025, m, 6 + r),
        'I avoid bringing up needs with my partner until resentment builds and we fight about small things.',
        'I avoid bringing up needs with my partner until resentment builds.',
        themes: const ['relationships', 'avoidance'],
      );
    }
  }

  add(
    _month(2024, 4, 8),
    'I told my partner everything is fine and I do not need more support right now.',
    'I tell my partner everything is fine when I need support.',
    themes: const ['relationships'],
  );
  add(
    _month(2024, 12, 8),
    'I admitted I have been lonely even when we are in the same room together.',
    'I feel lonely even when we are together.',
    themes: const ['relationships'],
    tensionOrContradiction: 'I say I am fine but I feel lonely.',
  );

  for (var k = 0; k < 32; k++) {
    add(
      _month(2025, 3, 1 + (k % 24)),
      'I avoid bringing up needs with my partner until resentment builds and we fight about small things.',
      'I avoid bringing up needs with my partner until resentment builds.',
      themes: const ['relationships', 'avoidance'],
    );
  }

  out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return out.take(200).toList();
}

List<JournalEntry> _fitnessEntries() {
  final out = <JournalEntry>[];
  var i = 0;
  void add(
    DateTime at,
    String t,
    String obs, {
    List<String> themes = const ['health'],
    String tensionOrContradiction = '',
  }) {
    out.add(
      _e(
        id: 'x${i++}',
        at: at,
        transcript: t,
        observation: obs,
        themes: themes,
        tensionOrContradiction: tensionOrContradiction,
      ),
    );
  }

  // Strong early discipline
  for (var m = 1; m <= 4; m++) {
    for (var r = 0; r < 7; r++) {
      add(
        _month(2024, m, 2 + r),
        'I never skip training when I commit to a program — discipline is non-negotiable for me.',
        'Discipline around training is non-negotiable for me.',
        themes: const ['health', 'confidence'],
      );
    }
  }

  // Emerging: sleep-driven skips
  for (var m = 5; m <= 12; m++) {
    for (var r = 0; r < (m < 9 ? 2 : 6); r++) {
      add(
        _month(2024, m, 8 + r),
        'I skip training when sleep is poor even though consistency matters more to me than perfect sessions.',
        'I skip training when sleep is poor even though consistency matters to me.',
        themes: const ['health'],
      );
    }
  }

  add(
    _month(2024, 3, 9),
    'Rest days are for recovery and missing a workout does not mean I failed.',
    'Rest days are recovery and missing a workout is not failure.',
    themes: const ['health'],
  );
  add(
    _month(2024, 10, 9),
    'I beat myself up when I miss a workout and I feel like I lost discipline entirely.',
    'I beat myself up when I miss a workout and feel undisciplined.',
    themes: const ['health', 'approval'],
    tensionOrContradiction: 'I say rest is fine but I punish myself for missing sessions.',
  );

  for (var k = 0; k < 10; k++) {
    add(
      _month(2025, 1, 5 + k),
      'I trained anyway on five hours of sleep because I refuse to break the streak.',
      'I trained on low sleep to keep the streak alive.',
      themes: const ['health'],
    );
  }

  for (var k = 0; k < 42; k++) {
    add(
      _month(2025, 2 + (k % 4), 2 + (k % 22)),
      'I skip training when sleep is poor even though consistency matters more to me than perfect sessions.',
      'I skip training when sleep is poor even though consistency matters to me.',
      themes: const ['health'],
    );
  }

  out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return out.take(200).toList();
}
