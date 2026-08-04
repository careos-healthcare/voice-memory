import '../../media/media_attachment.dart';

enum ManualNodeCategory { person, habit, emotion, goal, idea }

class ManualNodeDraft {
  const ManualNodeDraft({
    required this.label,
    required this.category,
    this.note,
    this.mediaAttachments = const [],
  });

  final String label;
  final ManualNodeCategory category;
  final String? note;
  final List<MediaAttachment> mediaAttachments;
}
