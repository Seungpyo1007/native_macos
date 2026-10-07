import 'package:flutter/widgets.dart';

import 'native_channel.dart';
import 'native_support.dart';
import 'native_view.dart';

/// The icon and urgency of a native alert (`NSAlert.Style`).
enum NativeAlertStyle { warning, informational, critical }

/// A button in [showNativeAlert].
class NativeAlertButton {
  const NativeAlertButton(
    this.title, {
    this.destructive = false,
    this.isDefault = false,
    this.isCancel = false,
  });

  final String title;

  /// Shows the button as destructive (`hasDestructiveAction`).
  final bool destructive;

  /// Makes Return press this button. Without one, the first button is the
  /// default, as in AppKit.
  final bool isDefault;

  /// Makes Escape press this button. Without one, AppKit picks a button
  /// titled "Cancel" or "Don't Save". A button that is also [isDefault]
  /// takes Return instead.
  final bool isCancel;
}

/// Shows an `NSAlert` and returns the index of the pressed button in
/// [buttons], or -1 if it closed without one.
///
/// With [asSheet], the alert slides down from the window's title bar;
/// otherwise it is an app-modal window. Throws [UnsupportedError] off macOS
/// and `NativeMacosException` when the Flutter view has no window.
Future<int> showNativeAlert({
  required BuildContext context,
  required String title,
  String? message,
  required List<NativeAlertButton> buttons,
  NativeAlertStyle style = NativeAlertStyle.warning,
  bool asSheet = true,
}) async {
  if (!NativeMacos.isSupported) {
    throw UnsupportedError('showNativeAlert only works on macOS.');
  }
  if (buttons.isEmpty) {
    throw ArgumentError.value(buttons, 'buttons', 'must not be empty');
  }
  final index = await invokeNative<int>('showAlert', {
    'title': title,
    'message': message,
    'style': style.name,
    'asSheet': asSheet,
    'brightness': nativeBrightness(context).name,
    'buttons': [
      for (final b in buttons)
        {
          'title': b.title,
          'destructive': b.destructive,
          'isDefault': b.isDefault,
          'isCancel': b.isCancel,
        },
    ],
  });
  return index ?? 0;
}
