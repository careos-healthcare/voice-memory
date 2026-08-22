import 'package:archiveme_mobile/features/clinical_sandbox/runtime/clinical_sandbox_runtime.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/cognitive_analyzer.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Consent-gated wrapper around [CognitiveAnalyzer].
class ClinicalSandboxCognitiveAnalyzer {
  const ClinicalSandboxCognitiveAnalyzer({
    CognitiveAnalyzer? inner,
  }) : _inner = inner ?? const CognitiveAnalyzer();

  final CognitiveAnalyzer _inner;

  JournalEntry enrichEntry(JournalEntry entry) {
    if (!ClinicalSandboxRuntime.mayRunClinicalAnalysis) {
      return entry;
    }
    return _inner.enrichEntry(entry);
  }

  CognitiveBiomarkers? analyzeTranscript(String transcript) {
    if (!ClinicalSandboxRuntime.mayRunClinicalAnalysis) return null;
    return _inner.analyzeTranscript(transcript);
  }
}