enum DiffLineKind { unchanged, added, removed }

class DiffLine {
  const DiffLine({required this.kind, required this.text});

  final DiffLineKind kind;
  final String text;

  bool get selectable => kind != DiffLineKind.unchanged;
}

/// Line diff of the on-device transcript against the incoming peer version.
List<DiffLine> buildLineDiff(String local, String remote) {
  final left = _lines(local);
  final right = _lines(remote);
  final rows = <DiffLine>[];
  var i = 0;
  var j = 0;
  while (i < left.length && j < right.length) {
    if (left[i] == right[j]) {
      rows.add(DiffLine(kind: DiffLineKind.unchanged, text: left[i]));
      i++;
      j++;
      continue;
    }
    final remoteAhead = right.indexOf(left[i], j + 1);
    final localAhead = left.indexOf(right[j], i + 1);
    if (remoteAhead == -1 && localAhead == -1) {
      rows
        ..add(DiffLine(kind: DiffLineKind.removed, text: left[i]))
        ..add(DiffLine(kind: DiffLineKind.added, text: right[j]));
      i++;
      j++;
    } else if (remoteAhead == -1 ||
        (localAhead != -1 && localAhead - i <= remoteAhead - j)) {
      rows.add(DiffLine(kind: DiffLineKind.removed, text: left[i]));
      i++;
    } else {
      rows.add(DiffLine(kind: DiffLineKind.added, text: right[j]));
      j++;
    }
  }
  while (i < left.length) {
    rows.add(DiffLine(kind: DiffLineKind.removed, text: left[i]));
    i++;
  }
  while (j < right.length) {
    rows.add(DiffLine(kind: DiffLineKind.added, text: right[j]));
    j++;
  }
  return rows;
}

/// Keeps unchanged lines plus the changed lines the user left checked.
String combineSelectedLines(List<DiffLine> rows, List<bool> selected) {
  final out = <String>[];
  var cursor = 0;
  for (final row in rows) {
    if (!row.selectable) {
      out.add(row.text);
      continue;
    }
    if (cursor < selected.length && selected[cursor]) {
      out.add(row.text);
    }
    cursor++;
  }
  return out.join('\n');
}

List<String> _lines(String value) {
  if (value.isEmpty) return const [];
  return value.split('\n');
}
