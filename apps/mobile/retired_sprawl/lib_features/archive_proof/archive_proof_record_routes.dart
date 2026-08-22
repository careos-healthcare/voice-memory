/// Guided recording entry points for archive proof flows.
abstract final class ArchiveProofRecordRoutes {
  static const changeTimelineNodeKey = 'changeTimeline';

  static const changeTimelinePrompt =
      'Record one ordinary moment — notice if something familiar is showing up again.';

  static String? promptForGuidedNode(String? nodeKey) {
    if (nodeKey == changeTimelineNodeKey) return changeTimelinePrompt;
    return null;
  }

  static String uri({String? guidedPromptNodeKey}) {
    if (guidedPromptNodeKey == null || guidedPromptNodeKey.isEmpty) {
      return '/record';
    }
    return '/record?guidedPromptNodeKey=$guidedPromptNodeKey';
  }
}