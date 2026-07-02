import 'archive_thought_map_models.dart';

/// Consumer copy for the Patterns thought map preview.
abstract final class ArchiveThoughtMapCopy {
  ArchiveThoughtMapCopy._();

  static const sectionTitle = 'Thought map preview';
  static const stageLabelPrefix = 'Signal:';

  static const triggerLabel = 'Trigger';
  static const thoughtLabel = 'Thought';
  static const behaviourLabel = 'Behaviour';
  static const reliefLabel = 'Relief';
  static const costLabel = 'Cost';
  static const alternativeLabel = 'Alternative / next test';

  static const connectorBecause = 'because';
  static const connectorSo = 'so';
  static const connectorBut = 'but';
  static const connectorNext = 'next';

  static const changePrefix = 'Changed: ';

  static const feelsRightCta = 'This feels right';
  static const renameThreadCta = 'Rename thread';
  static const notQuiteCta = 'Not quite';

  static const feelsRightConfirmation =
      'Saved. ArchiveMe will keep this thread visible.';
  static const notQuiteMessage =
      'ArchiveMe will wait for more evidence before naming this thread.';

  static const renameFieldHint = 'Thread title';
  static const renameSaveCta = 'Save title';
  static const threadRenamedConfirmation = 'Thread renamed';

  static const whyNodeAppearsTitle = 'Evidence for this node';
  static const nodeEvidenceFallback =
      'ArchiveMe needs more saved moments before it can explain this node.';
  static const patternSignalDisclaimer =
      'This is a local pattern signal, not a diagnosis.';
  static const recordAnotherMomentCta = 'Record another moment';
  static const closeCta = 'Close';

  static String evidenceLine(int savedMomentCount) {
    final count = savedMomentCount.clamp(0, 9999);
    final noun = count == 1 ? 'moment' : 'moments';
    return 'Built from $count saved $noun';
  }

  static String savedAtLabel(DateTime savedAt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[savedAt.month - 1]} ${savedAt.day}';
  }

  static String connectorLabel(ArchiveThoughtMapConnector connector) =>
      switch (connector) {
        ArchiveThoughtMapConnector.because => connectorBecause,
        ArchiveThoughtMapConnector.so => connectorSo,
        ArchiveThoughtMapConnector.but => connectorBut,
        ArchiveThoughtMapConnector.next => connectorNext,
      };

  static String nodeKindLabel(ArchiveThoughtMapNodeKind kind) => switch (kind) {
        ArchiveThoughtMapNodeKind.trigger => triggerLabel,
        ArchiveThoughtMapNodeKind.thought => thoughtLabel,
        ArchiveThoughtMapNodeKind.behaviour => behaviourLabel,
        ArchiveThoughtMapNodeKind.relief => reliefLabel,
        ArchiveThoughtMapNodeKind.cost => costLabel,
        ArchiveThoughtMapNodeKind.alternative => alternativeLabel,
      };

  static List<String> get allVisibleStrings => [
        sectionTitle,
        stageLabelPrefix,
        triggerLabel,
        thoughtLabel,
        behaviourLabel,
        reliefLabel,
        costLabel,
        alternativeLabel,
        connectorBecause,
        connectorSo,
        connectorBut,
        connectorNext,
        changePrefix,
        feelsRightCta,
        renameThreadCta,
        notQuiteCta,
        feelsRightConfirmation,
        notQuiteMessage,
        renameFieldHint,
        renameSaveCta,
        threadRenamedConfirmation,
        whyNodeAppearsTitle,
        nodeEvidenceFallback,
        patternSignalDisclaimer,
        recordAnotherMomentCta,
        closeCta,
        evidenceLine(1),
        evidenceLine(4),
        '${changePrefix}repeated',
      ];
}
