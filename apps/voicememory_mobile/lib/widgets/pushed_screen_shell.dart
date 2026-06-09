import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Standard pushed-route chrome: back, scroll body, optional bottom Done.
class PushedScreenShell extends StatelessWidget {
  const PushedScreenShell({
    super.key,
    required this.title,
    required this.body,
    this.doneLabel = 'Done',
    this.showBottomDone = true,
    this.fallbackRoute = '/archive-belief',
    this.actions,
    this.backgroundColor = AppTheme.background,
  });

  final String title;
  final Widget body;
  final String doneLabel;
  final bool showBottomDone;
  final String fallbackRoute;
  final List<Widget>? actions;
  final Color backgroundColor;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
        title: Text(title),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: showBottomDone
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _goBack(context),
                    child: Text(doneLabel),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
