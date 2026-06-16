import 'package:flutter/foundation.dart';

/// Selection state for one archive surface (search results, pinned
/// evidence, or a collection detail list). Pure UI state: ids only,
/// nothing here reads or writes entries.
class ArchiveSelectionController extends ChangeNotifier {
  var _selecting = false;
  final Set<String> _selected = <String>{};

  bool get selecting => _selecting;
  Set<String> get selectedIds => Set.unmodifiable(_selected);
  int get count => _selected.length;
  bool isSelected(String id) => _selected.contains(id);

  void start() {
    if (_selecting) return;
    _selecting = true;
    notifyListeners();
  }

  /// Leaves select mode and clears the selection.
  void cancel() {
    if (!_selecting && _selected.isEmpty) return;
    _selecting = false;
    _selected.clear();
    notifyListeners();
  }

  void toggle(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    _selected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}
