import 'package:flutter/foundation.dart';

@immutable
class SearchGraphFocusState {
  const SearchGraphFocusState({required this.nodeId, required this.revision});

  final String? nodeId;
  final int revision;
}

class SearchGraphFocus extends ChangeNotifier
    implements ValueListenable<SearchGraphFocusState> {
  SearchGraphFocusState _value = const SearchGraphFocusState(
    nodeId: null,
    revision: 0,
  );

  @override
  SearchGraphFocusState get value => _value;

  void focus(String nodeId) {
    _value = SearchGraphFocusState(
      nodeId: nodeId,
      revision: _value.revision + 1,
    );
    notifyListeners();
  }

  void clear() {
    if (_value.nodeId == null) return;
    _value = SearchGraphFocusState(nodeId: null, revision: _value.revision + 1);
    notifyListeners();
  }
}
