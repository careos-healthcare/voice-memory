import 'dart:convert';
import 'dart:io';

void main() {
  final j =
      jsonDecode(
            File('tool/output/archive_quality_raw.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final s in j['scenarios'] as List) {
    final m = s as Map<String, dynamic>;
    stdout.writeln(
      '=== ${m['persona']} @ ${m['reflectionCount']} (eligible ${m['eligibleCount']}, ${m['analystLevel']}) ===',
    );
    if ((m['reflectionCount'] as int) < 50) {
      stdout.writeln('  gated\n');
      continue;
    }
    final v1 = m['v1'] as Map<String, dynamic>;
    final belief = v1['belief'] as Map<String, dynamic>?;
    if (belief != null) {
      stdout.writeln(
        '  V1: ${belief['statement']} (${belief['confidencePercent']}%)',
      );
    }
    final a = m['analyst'] as Map<String, dynamic>;
    stdout.writeln('  Current (${(a['currentBeliefs'] as List).length}):');
    for (final b in (a['currentBeliefs'] as List).take(4)) {
      final row = b as Map<String, dynamic>;
      stdout.writeln(
        '    ${row['confidencePercent']}% ev=${row['evidenceCount']} ctr=${row['counterEvidenceCount']} | ${row['statement']}',
      );
    }
    stdout.writeln(
      '  Emerging ${(a['emergingBeliefs'] as List).length} / Fading ${(a['fadingBeliefs'] as List).length}',
    );
    for (final e in (a['emergingBeliefs'] as List).take(2)) {
      final row = e as Map<String, dynamic>;
      stdout.writeln('    ↑ ${row['trendLabel']}');
      stdout.writeln('      ${row['statement']}');
    }
    for (final f in (a['fadingBeliefs'] as List).take(2)) {
      final row = f as Map<String, dynamic>;
      stdout.writeln('    ↓ ${row['trendLabel']}');
      stdout.writeln('      ${row['statement']}');
    }
    stdout.writeln('  Contradictions ${(a['contradictions'] as List).length}:');
    for (final c in (a['contradictions'] as List).take(2)) {
      final row = c as Map<String, dynamic>;
      stdout.writeln('    • ${row['youSay']}');
      stdout.writeln('      vs ${row['but']}');
    }
    stdout.writeln('  Blind spots ${(a['blindSpots'] as List).length}:');
    for (final b in (a['blindSpots'] as List).take(2)) {
      final row = b as Map<String, dynamic>;
      stdout.writeln('    • ${row['headline']}');
    }
    stdout.writeln('  Competing:');
    for (final c in (a['competingBeliefs'] as List)) {
      final row = c as Map<String, dynamic>;
      stdout.writeln(
        '    ${row['isPrimary'] == true ? '*' : ' '} ${row['confidencePercent']}% ${row['statement']}',
      );
    }
    stdout.writeln('  Debates ${(a['debates'] as List).length}:');
    for (final d in (a['debates'] as List).take(2)) {
      final row = d as Map<String, dynamic>;
      stdout.writeln(
        '    ${row['beliefStatement']} (for ${row['evidenceForCount']} / against ${row['evidenceAgainstCount']})',
      );
      if (row['firstCounterQuote'] != null) {
        stdout.writeln('      counter: ${row['firstCounterQuote']}');
      }
    }
    final metrics = m['metrics'] as Map<String, dynamic>;
    if ((metrics['genericPhraseHits'] as List).isNotEmpty) {
      stdout.writeln('  GENERIC: ${metrics['genericPhraseHits']}');
    }
    if ((metrics['counterExceedsSupport'] as List).isNotEmpty) {
      stdout.writeln('  COUNTER>Support: ${metrics['counterExceedsSupport']}');
    }
    stdout.writeln();
  }
  stdout.writeln('Cross-persona dupes: ${j['crossPersonaDuplicateBeliefs']}');
}
