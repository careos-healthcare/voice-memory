// Living Archive v1 — presentation-only status, pulse, and return reason for mobile.

enum ArchiveLivingStatusMobile {
  learning,
  investigating,
  strengthening,
  uncertain,
  revising,
  stable,
}

class ArchiveStatusMobileView {
  const ArchiveStatusMobileView({
    required this.status,
    required this.label,
    required this.line,
  });

  final ArchiveLivingStatusMobile status;
  final String label;
  final String line;
}

class ArchivePulseMobileView {
  const ArchivePulseMobileView({required this.line});
  final String line;
}

class ArchiveReasonMobileView {
  const ArchiveReasonMobileView({required this.line});
  final String line;
}

const _statusLabels = {
  ArchiveLivingStatusMobile.learning: 'Learning',
  ArchiveLivingStatusMobile.investigating: 'Investigating',
  ArchiveLivingStatusMobile.strengthening: 'Strengthening',
  ArchiveLivingStatusMobile.uncertain: 'Uncertain',
  ArchiveLivingStatusMobile.revising: 'Revising',
  ArchiveLivingStatusMobile.stable: 'Stable',
};

const _statusLines = {
  ArchiveLivingStatusMobile.learning:
      'Your archive is still gathering a working belief.',
  ArchiveLivingStatusMobile.investigating: 'New evidence is still arriving.',
  ArchiveLivingStatusMobile.strengthening: 'This belief is gaining support.',
  ArchiveLivingStatusMobile.uncertain:
      'The archive is weighing conflicting evidence.',
  ArchiveLivingStatusMobile.revising:
      'The archive is reconsidering one belief.',
  ArchiveLivingStatusMobile.stable: 'This belief has remained consistent.',
};

ArchiveLivingStatusMobile deriveMobileArchiveLivingStatus({
  required int reflectionCount,
  bool hasDeltaChanges = false,
  bool beliefActive = false,
}) {
  if (reflectionCount < 3) return ArchiveLivingStatusMobile.learning;
  if (hasDeltaChanges && !beliefActive) {
    return ArchiveLivingStatusMobile.investigating;
  }
  if (hasDeltaChanges) return ArchiveLivingStatusMobile.revising;
  if (reflectionCount >= 5 && beliefActive) {
    return ArchiveLivingStatusMobile.stable;
  }
  if (beliefActive) return ArchiveLivingStatusMobile.strengthening;
  return ArchiveLivingStatusMobile.investigating;
}

ArchiveStatusMobileView buildMobileArchiveStatus({
  required int reflectionCount,
  bool hasDeltaChanges = false,
  bool beliefActive = false,
}) {
  final status = deriveMobileArchiveLivingStatus(
    reflectionCount: reflectionCount,
    hasDeltaChanges: hasDeltaChanges,
    beliefActive: beliefActive,
  );
  return ArchiveStatusMobileView(
    status: status,
    label: _statusLabels[status]!,
    line: _statusLines[status]!,
  );
}

ArchivePulseMobileView? buildMobileArchivePulse({
  required int reflectionCount,
  bool hasDeltaChanges = false,
  bool beliefActive = false,
}) {
  if (reflectionCount < 1) return null;
  if (hasDeltaChanges) {
    return const ArchivePulseMobileView(
      line: 'The archive is reconsidering one belief.',
    );
  }
  if (beliefActive && reflectionCount >= 5) {
    return const ArchivePulseMobileView(
      line: 'The archive became more certain this week.',
    );
  }
  if (reflectionCount >= 5) {
    return const ArchivePulseMobileView(
      line: 'The archive has not seen evidence for this recently.',
    );
  }
  return null;
}

ArchiveReasonMobileView? buildMobileArchiveReasonToReturn({
  required int reflectionCount,
  bool hasDeltaChanges = false,
  bool beliefActive = false,
}) {
  final pulse = buildMobileArchivePulse(
    reflectionCount: reflectionCount,
    hasDeltaChanges: hasDeltaChanges,
    beliefActive: beliefActive,
  );
  if (pulse != null) {
    var line = pulse.line;
    if (line.startsWith('The archive ')) {
      line = 'Your archive ${line.substring(13)}';
    }
    return ArchiveReasonMobileView(line: line);
  }
  if (hasDeltaChanges) {
    return const ArchiveReasonMobileView(
      line: 'Your archive changed since you last looked.',
    );
  }
  return null;
}
