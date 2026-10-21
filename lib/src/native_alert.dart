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

/// A text field in a native alert (`NSAlert.accessoryView`).
final class NativeAlertTextField {
  const NativeAlertTextField({
    this.text = '',
    this.placeholder,
    this.secure = false,
  });

  /// The text the field starts with.
  final String text;

  final String? placeholder;

  /// Hides the typed characters, for passwords (`NSSecureTextField`).
  final bool secure;
}

/// How a native alert from [showNativeAlertWithResult] closed.
final class NativeAlertResult {
  const NativeAlertResult({
    required this.index,
    this.suppressed = false,
    this.text,
  });

  /// The index of the pressed button, or -1 if it closed without one.
  final int index;

  /// Whether the suppression checkbox ("Do not show this again") was on.
  final bool suppressed;

  /// The text field's text, or null when the alert had none.
  final String? text;
}

/// Shows an `NSAlert` and returns the index of the pressed button in
/// [buttons], or -1 if it closed without one.
///
/// With [asSheet], the alert slides down from the window's title bar;
/// otherwise it is an app-modal window. Throws [UnsupportedError] off macOS
/// and `NativeMacosException` when a sheet has no window to attach to.
///
/// Use [showNativeAlertWithResult] for a suppression checkbox or a text
/// field.
Future<int> showNativeAlert({
  required BuildContext context,
  required String title,
  String? message,
  required List<NativeAlertButton> buttons,
  NativeAlertStyle style = NativeAlertStyle.warning,
  bool asSheet = true,
}) async {
  final index = await invokeNative<int>(
    'showAlert',
    _alertArguments(context, title, message, buttons, style, asSheet),
  );
  return index ?? 0;
}

/// Shows an `NSAlert` like [showNativeAlert], optionally with a suppression
/// checkbox labeled [suppressionLabel] and a [textField], and returns how it
/// closed.
///
/// [suppressed] is the checkbox's starting state. The text field has the
/// keyboard focus when the alert opens.
Future<NativeAlertResult> showNativeAlertWithResult({
  required BuildContext context,
  required String title,
  String? message,
  required List<NativeAlertButton> buttons,
  NativeAlertStyle style = NativeAlertStyle.warning,
  bool asSheet = true,
  String? suppressionLabel,
  bool suppressed = false,
  NativeAlertTextField? textField,
}) async {
  final reply = await invokeNative<Map<Object?, Object?>>('showAlert', {
    ..._alertArguments(context, title, message, buttons, style, asSheet),
    'detailed': true,
    'suppressionLabel': suppressionLabel,
    'suppressed': suppressed,
    if (textField != null)
      'textField': {
        'text': textField.text,
        'placeholder': textField.placeholder,
        'secure': textField.secure,
      },
  });
  return NativeAlertResult(
    index: reply?['index'] as int? ?? -1,
    suppressed: reply?['suppressed'] as bool? ?? false,
    text: reply?['text'] as String?,
  );
}

Map<String, Object?> _alertArguments(
  BuildContext context,
  String title,
  String? message,
  List<NativeAlertButton> buttons,
  NativeAlertStyle style,
  bool asSheet,
) {
  if (!NativeMacos.isSupported) {
    throw UnsupportedError('showNativeAlert only works on macOS.');
  }
  if (buttons.isEmpty) {
    throw ArgumentError.value(buttons, 'buttons', 'must not be empty');
  }
  return {
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
  };
}
