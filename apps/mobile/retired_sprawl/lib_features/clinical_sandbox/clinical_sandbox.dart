/// Isolated compliance-gated clinical-signal sandbox.
///
/// Biomarker, trajectory, and anomaly analysis code is exported here for
/// regulatory review. Runtime execution requires the compile-time feature
/// flag, developer token, and explicit licensed-provider consent.
library;

// Quarantined analysis primitives (source: curiosity_loop).
export '../curiosity_loop/domain/models/cognitive_biomarkers.dart';
export '../curiosity_loop/domain/services/cognitive_anomaly_detector.dart';
export '../curiosity_loop/domain/services/cognitive_trajectory_evaluator.dart';
export '../curiosity_loop/repositories/clinical_trajectory_history_store.dart';
export 'config/clinical_sandbox_feature_flags.dart';
export 'data/clinical_data_governance.dart';
export 'domain/clinical_sandbox_cognitive_analyzer.dart';
export 'gates/clinical_consent_gate.dart';
export 'pipeline/clinical_sandbox_pipeline.dart';
export 'presentation/clinical_consent_copy.dart';
export 'runtime/clinical_sandbox_runtime.dart';
export 'stores/clinical_consent_store.dart';
export 'views/clinical_consent_disclaimer_view.dart';
export 'views/clinical_sandbox_consent_screen.dart';