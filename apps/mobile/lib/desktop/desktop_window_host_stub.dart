import 'package:flutter/widgets.dart';

/// Mobile and web host. This file does not import `window_manager`.
bool get desktopWindowIsHost => false;

Future<void> initializeDesktopWindow() async {}

Widget desktopWindowChrome() => const SizedBox.shrink();
