import 'proof_of_value_copy.dart';

enum ProofOfValueRowId {
  firstSave,
  secondSave,
  firstProof,
  coreValueYes,
  feltGeneric,
  wouldKeepUsing,
  wouldPay,
  returnCheck,
}

enum ProofOfValueSummaryState {
  notEnoughEvidence,
  activationNotProven,
  firstProofNotProven,
  specificityNotProven,
  retentionNotProven,
  paymentNotProven,
  emerging,
  strong,
}

enum ProofOfValueRecommendation {
  runMoreTesters,
  fixFirstUse,
  fixReturnLoop,
  fixFirstProof,
  fixEvidence,
  strengthenRetention,
  strengthenPro,
  widenBeta,
}

enum ProofOfValueRowStatus {
  proven,
  notProven,
  warning,
  checkManually,
  notEnoughData;

  String get label => switch (this) {
        ProofOfValueRowStatus.proven => ProofOfValueCopy.statusProven,
        ProofOfValueRowStatus.notProven => ProofOfValueCopy.statusNotProven,
        ProofOfValueRowStatus.warning => ProofOfValueCopy.statusWarning,
        ProofOfValueRowStatus.checkManually =>
          ProofOfValueCopy.statusCheckManually,
        ProofOfValueRowStatus.notEnoughData =>
          ProofOfValueCopy.statusNotEnoughData,
      };
}

/// Local and optional manual beta proof inputs — counts only, no journal text.
class ProofOfValueInput {
  const ProofOfValueInput({
    this.totalTesters = 0,
    this.appOpened = 0,
    this.firstMomentSaved = 0,
    this.secondMomentSaved = 0,
    this.firstProofReached = 0,
    this.returnCheckAnswered = 0,
    this.proTapped = 0,
    this.coreValueYes,
    this.coreValueNotYet,
    this.coreValueGeneric,
    this.localCoreValueAnswerLabel,
    this.proofFeltSpecific,
    this.proofUsefulCount,
    this.wouldKeepUsing,
    this.wouldPay,
  });

  final int totalTesters;
  final int appOpened;
  final int firstMomentSaved;
  final int secondMomentSaved;
  final int firstProofReached;
  final int returnCheckAnswered;
  final int proTapped;
  final int? coreValueYes;
  final int? coreValueNotYet;
  final int? coreValueGeneric;
  final String? localCoreValueAnswerLabel;
  final int? proofFeltSpecific;
  final int? proofUsefulCount;
  final int? wouldKeepUsing;
  final int? wouldPay;
}

class ProofOfValueRow {
  const ProofOfValueRow({
    required this.id,
    required this.label,
    required this.question,
    required this.currentValue,
    required this.targetValue,
    required this.status,
  });

  final ProofOfValueRowId id;
  final String label;
  final String question;
  final String currentValue;
  final String targetValue;
  final ProofOfValueRowStatus status;
}

class ProofOfValueReport {
  const ProofOfValueReport({
    required this.title,
    required this.primaryQuestion,
    required this.summary,
    required this.summaryState,
    required this.recommendation,
    required this.rows,
    this.localCoreValueNote,
  });

  final String title;
  final String primaryQuestion;
  final String summary;
  final ProofOfValueSummaryState summaryState;
  final String recommendation;
  final List<ProofOfValueRow> rows;
  final String? localCoreValueNote;

  List<String> get visibleCopyBlocks => [
        title,
        primaryQuestion,
        summary,
        recommendation,
        if (localCoreValueNote != null) localCoreValueNote!,
        for (final row in rows) ...[
          row.label,
          row.question,
          row.currentValue,
          row.targetValue,
          row.status.label,
        ],
      ];
}
