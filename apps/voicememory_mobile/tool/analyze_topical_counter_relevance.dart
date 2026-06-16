import 'dart:convert';
import 'dart:io';

/// Reads counterEvidenceRelevance from archive_quality_raw.json (written by validation test).
void main() {
  final raw = File('tool/output/archive_quality_raw.json');
  if (!raw.existsSync()) {
    stderr.writeln(
      'Missing ${raw.path}. Run archive_quality_validation_test first.',
    );
    exit(1);
  }
  final j = jsonDecode(raw.readAsStringSync()) as Map<String, dynamic>;
  final relevance = j['counterEvidenceRelevance'] as Map<String, dynamic>?;
  if (relevance == null) {
    stderr.writeln('Missing counterEvidenceRelevance in ${raw.path}.');
    exit(1);
  }

  final relevant = relevance['relevant'] as int;
  final total = relevance['total'] as int;
  final rate = relevance['relevanceRate'] as num;
  final targetMet = relevance['targetMet'] == true;

  print('--- Topical counter relevance (from validation harness) ---');
  print('Relevant: $relevant / $total (${(rate * 100).toStringAsFixed(1)}%)');
  print('Target > 85%: ${targetMet ? 'PASS' : 'FAIL'}');

  final out = File('tool/output/topical_counter_relevance.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(relevance));
  print('Written: ${out.path}');

  if (!targetMet) exit(1);
}
