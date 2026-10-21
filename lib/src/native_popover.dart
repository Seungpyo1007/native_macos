import 'package:flutter/widgets.dart';

import 'native_channel.dart';
import 'native_support.dart';
import 'native_view.dart';

/// The side of the anchor a native popover prefers. AppKit picks another
/// one when there is no room.
enum NativePopoverEdge { top, bottom, leading, trailing }

/// A button in [showNativePopover].
final class NativePopoverAction<T> {
  const NativePopoverAction(
    this.title, {
    required this.value,
    this.isDefault = false,
    this.destructive = false,
  });

  final String title;

  final T value;

  /// Makes Return press this button.
  final bool isDefault;

  /// Shows the button as destructive (`hasDestructiveAction`).
  final bool destructive;
}

/// Shows an `NSPopover` with [title], [message], and [actions] pointing at
/// [anchor], a rect in global coordinates such as
/// `box.localToGlobal(Offset.zero) & box.size`.
///
/// Returns the value of the pressed action, or null when the popover closes
/// another way: a click outside, Escape, or a newer popover. Throws
/// [UnsupportedError] off macOS and `NativeMacosException` when the Flutter
/// view has no window.
Future<T?> showNativePopover<T>({
  required BuildContext context,
  required Rect anchor,
  String? title,
  String? message,
  List<NativePopoverAction<T>> actions = const [],
  NativePopoverEdge edge = NativePopoverEdge.bottom,
  double maxWidth = 280,
}) async {
  if (!NativeMacos.isSupported) {
    throw UnsupportedError('showNativePopover only works on macOS.');
  }
  if (title == null && message == null && actions.isEmpty) {
    throw ArgumentError('A popover needs a title, a message, or actions.');
  }
  final index = await invokeNative<int>('showPopover', {
    'x': anchor.left,
    'y': anchor.top,
    'width': anchor.width,
    'height': anchor.height,
    'title': title,
    'message': message,
    'edge': edge.name,
    'maxWidth': maxWidth,
    'brightness': nativeBrightness(context).name,
    'rtl': Directionality.maybeOf(context) == TextDirection.rtl,
    'actions': [
      for (final a in actions)
        {
          'title': a.title,
          'isDefault': a.isDefault,
          'destructive': a.destructive,
        },
    ],
  });
  if (index == null || index < 0 || index >= actions.length) return null;
  return actions[index].value;
}
