import 'package:flutter/widgets.dart';

/// Stops native views below it from taking clicks while [blocked].
///
/// On macOS, AppKit views take clicks anywhere Flutter has not painted, even
/// under a transparent dialog or menu barrier. Wrap the page in a
/// [NativeInputBlocker] and set [blocked] while an overlay is open. An inner
/// blocker cannot unblock what an outer one blocks.
class NativeInputBlocker extends StatelessWidget {
  const NativeInputBlocker({
    super.key,
    required this.blocked,
    required this.child,
  });

  /// Whether native views below this widget ignore clicks.
  final bool blocked;

  final Widget child;

  /// Whether any [NativeInputBlocker] above [context] blocks input.
  static bool isBlocked(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BlockerScope>()?.blocked ??
      false;

  @override
  Widget build(BuildContext context) =>
      _BlockerScope(blocked: blocked || isBlocked(context), child: child);
}

class _BlockerScope extends InheritedWidget {
  const _BlockerScope({required this.blocked, required super.child});

  final bool blocked;

  @override
  bool updateShouldNotify(_BlockerScope oldWidget) =>
      blocked != oldWidget.blocked;
}
