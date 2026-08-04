const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A full, unambiguous date. Evidence is always dated in words the reader can
/// check against their own memory, never as a relative "3 days ago".
String formatFullDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

String formatDateRange(DateTime first, DateTime latest) {
  final start = formatFullDate(first);
  final end = formatFullDate(latest);
  return start == end ? start : '$start — $end';
}
