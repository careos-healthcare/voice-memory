import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a Riverpod scope is available above [context].
///
/// Production always wraps the app in a scope (see `App`), so this returns true
/// there. It exists so non-essential sync-status chrome can degrade gracefully
/// instead of throwing "No ProviderScope found" when a lightweight widget test
/// pumps a screen (which carries the app AppBar/shell) without app DI.
bool hasRiverpodScope(BuildContext context) =>
    context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
    context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null;
