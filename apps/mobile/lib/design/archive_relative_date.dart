/// Relative labels for archive “last updated” surfaces.
String formatArchiveRelativeUpdate(DateTime? dateTime) {
  if (dateTime == null) return 'not yet';
  final diff = DateTime.now().difference(dateTime.toLocal());
  if (diff.inDays <= 0) {
    if (diff.inHours < 1) return 'just now';
    return 'today';
  }
  if (diff.inDays == 1) return '1 day ago';
  return '${diff.inDays} days ago';
}