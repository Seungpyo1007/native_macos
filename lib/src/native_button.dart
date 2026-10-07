import 'package:flutter/cupertino.dart';

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// An AppKit `NSButton`.
///
/// A null [onPressed] disables the button.
class NativeButton extends StatelessWidget {
  const NativeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.symbol,
    this.style = NativeButtonStyle.automatic,
    this.prominence = NativeTintProminence.automatic,
    this.borderShape = NativeBorderShape.automatic,
    this.controlSize = NativeControlSize.regular,
    this.tint,
    this.destructive = false,
    this.fallback,
  });

  final String label;

  final VoidCallback? onPressed;

  /// An SF Symbol name, such as `square.and.arrow.up`, shown before [label].
  final String? symbol;

  final NativeButtonStyle style;

  /// [NativeTintProminence.primary] marks the preferred action.
  final NativeTintProminence prominence;

  final NativeBorderShape borderShape;

  final NativeControlSize controlSize;

  /// Null uses the user's accent color.
  final Color? tint;

  /// Marks the button as destructive (`hasDestructiveAction`).
  final bool destructive;

  /// Shown when native views are not supported. Defaults to a
  /// [CupertinoButton].
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return fallback ??
          CupertinoButton(onPressed: onPressed, child: Text(label));
    }
    return NativeView(
      viewType: 'button',
      enabled: onPressed != null,
      tint: tint,
      estimatedSize: Size(
        estimatedTextWidth(label, padding: symbol == null ? 24 : 44),
        estimatedControlHeight(controlSize.index),
      ),
      params: {
        'label': label,
        'symbol': symbol,
        'style': style.name,
        'prominence': prominence.name,
        'borderShape': borderShape.name,
        'controlSize': controlSize.name,
        'destructive': destructive,
      },
      onEvent: (method, _) {
        if (method == 'pressed') onPressed?.call();
      },
    );
  }
}
