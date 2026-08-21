import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/proof_admission/proof_admission_config.dart';

const _configRelativePath = 'config/proof_admission_weights.v1.json';
const _outputRelativePath =
    'lib/features/proof_admission/generated/proof_admission_weights.g.dart';

Future<void> main(List<String> arguments) async {
  final appRoot = File.fromUri(Platform.script).parent.parent;
  final configFile = File('${appRoot.path}/$_configRelativePath');
  final outputFile = File('${appRoot.path}/$_outputRelativePath');
  final rawConfig = await configFile.readAsString();

  // Generation must fail before emitting an invalid or partial adapter.
  ProofAdmissionConfig.fromJsonString(rawConfig);
  final decoded = jsonDecode(rawConfig) as Map<String, dynamic>;
  final canonicalJson = const JsonEncoder.withIndent('  ').convert(decoded);
  final generated = _render(canonicalJson);

  if (arguments.contains('--check')) {
    if (!await outputFile.exists() ||
        await outputFile.readAsString() != generated) {
      stderr.writeln(
        'Generated proof admission adapter is stale. Run: '
        'dart run tool/generate_proof_admission_weights.dart',
      );
      exitCode = 1;
    }
    return;
  }

  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(generated);
}

String _render(String canonicalJson) {
  return '''// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: $_configRelativePath

import '../proof_admission_config.dart';

const generatedProofAdmissionConfigJson = r\'\'\'
$canonicalJson
\'\'\';

final generatedProofAdmissionConfig = ProofAdmissionConfig.fromJsonString(
  generatedProofAdmissionConfigJson,
);
''';
}