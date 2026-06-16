/// First honest archive "aha" moment — copy and stable ids.
///
/// Surfaces when enough evidence exists; never fakes insight.
library;

import '../memory/memory_authority_frame.dart';
import '../memory/memory_control_model.dart';
import '../memory/memory_priority_decision.dart';

/// Stable analytics id for the aha card surface.
abstract class AhaMomentCardType {
  AhaMomentCardType._();

  static const String id = 'aha_moment';
}

/// All consumer copy — compile-time constants for test sweeps.
abstract class AhaMomentCopy {
  AhaMomentCopy._();

  static const String title = 'This came back again';
  static const String body = 'ArchiveMe noticed this returned in your archive.';
  static const String helperLine =
      'You can check the evidence or mark it as not related.';

  static const String cautiousTitle = 'This may be returning';
  static const String cautiousBody =
      'ArchiveMe found related evidence, but it is being treated cautiously.';

  static const String showEvidenceLabel = 'Show evidence';
  static const String usefulLabel = 'Useful';
  static const String notQuiteLabel = 'Not quite';
  static const String usefulThanks =
      'Thanks — ArchiveMe will give this connection more weight.';
  static const String notQuiteThanks =
      'Thanks — ArchiveMe will treat this cautiously.';

  static const List<String> all = [
    title,
    body,
    helperLine,
    cautiousTitle,
    cautiousBody,
    showEvidenceLabel,
    usefulLabel,
    notQuiteLabel,
    usefulThanks,
    notQuiteThanks,
  ];
}

/// One eligible first-aha candidate — metadata only, no private text.
class AhaMomentCandidate {
  const AhaMomentCandidate({
    required this.entryCount,
    required this.eligibleEntryCount,
    required this.memoryScope,
    required this.priorityBand,
    required this.authorityState,
    required this.useCautiousCopy,
    this.source = 'aha_engine',
  });

  final int entryCount;
  final int eligibleEntryCount;
  final String memoryScope;
  final String priorityBand;
  final MemoryAuthorityState authorityState;
  final bool useCautiousCopy;
  final String source;

  /// Underlying memory card the evidence sheet and controls use.
  static const MemoryCardType underlyingCardType = MemoryCardType.threadReturn;

  String get title =>
      useCautiousCopy ? AhaMomentCopy.cautiousTitle : AhaMomentCopy.title;

  String get body =>
      useCautiousCopy ? AhaMomentCopy.cautiousBody : AhaMomentCopy.body;

  String get authorityStateId => authorityState.id;
}
