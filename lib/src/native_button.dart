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
    this.isDefault = false,
    this.isCancel = false,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
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

  /// Makes Return press the button when Flutter does not handle the key,
  /// and draws it as the default button.
  final bool isDefault;

  /// Makes Escape press the button when Flutter does not handle the key.
  final bool isCancel;

  /// The VoiceOver label. Null keeps AppKit's, which reads the control's
  /// title.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the control (`toolTip`).
  final String? tooltip;

  /// Whether Tab and Full Keyboard Access can focus the control. While it
  /// has focus, key presses go to AppKit instead of Flutter.
  final bool focusable;

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
      semanticsLabel: semanticsLabel,
      tooltip: tooltip,
      focusable: focusable,
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
        'isDefault': isDefault,
        'isCancel': isCancel,
      },
      onEvent: (method, _) {
        if (method == 'pressed') onPressed?.call();
      },
    );
  }
}

/// The round AppKit help button with a question mark (`NSButton.BezelStyle
/// .helpButton`).
///
/// A null [onPressed] disables the button.
class NativeHelpButton extends StatelessWidget {
  const NativeHelpButton({
    super.key,
    required this.onPressed,
    this.semanticsLabel = 'Help',
    this.tooltip,
    this.focusable = false,
    this.fallback,
  });

  final VoidCallback? onPressed;

  /// The VoiceOver label.
  final String semanticsLabel;

  /// Shown when the pointer rests on the button (`toolTip`).
  final String? tooltip;

  /// Whether Tab and Full Keyboard Access can focus the button.
  final bool focusable;

  /// Shown when native views are not supported. Defaults to a
  /// [CupertinoButton] with a question mark.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return fallback ??
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            child: const Icon(CupertinoIcons.question_circle),
          );
    }
    return NativeView(
      viewType: 'button',
      semanticsLabel: semanticsLabel,
      tooltip: tooltip,
      focusable: focusable,
      enabled: onPressed != null,
      estimatedSize: const Size(23, 23),
      params: const {'kind': 'help'},
      onEvent: (method, _) {
        if (method == 'pressed') onPressed?.call();
      },
    );
  }
}

/// The AppKit disclosure triangle that shows and hides details
/// (`NSButton.BezelStyle.disclosure`).
///
/// A null [onChanged] disables it.
class NativeDisclosureButton extends StatefulWidget {
  const NativeDisclosureButton({
    super.key,
    required this.expanded,
    required this.onChanged,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
    this.fallback,
  });

  /// Whether the triangle points down.
  final bool expanded;

  final ValueChanged<bool>? onChanged;

  /// The VoiceOver label, such as the name of the section it shows.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the button (`toolTip`).
  final String? tooltip;

  /// Whether Tab and Full Keyboard Access can focus the button.
  final bool focusable;

  /// Shown when native views are not supported. Defaults to a turning
  /// chevron.
  final Widget? fallback;

  @override
  State<NativeDisclosureButton> createState() => _NativeDisclosureButtonState();
}

class _NativeDisclosureButtonState extends State<NativeDisclosureButton> {
  final _view = GlobalKey<NativeViewState>();

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      final onChanged = widget.onChanged;
      return widget.fallback ??
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(24, 24),
            onPressed: onChanged == null
                ? null
                : () => onChanged(!widget.expanded),
            child: AnimatedRotation(
              turns: widget.expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(CupertinoIcons.chevron_right, size: 14),
            ),
          );
    }
    return NativeView(
      key: _view,
      viewType: 'button',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      focusable: widget.focusable,
      enabled: widget.onChanged != null,
      estimatedSize: const Size(13, 13),
      params: {'kind': 'disclosure', 'value': widget.expanded},
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        widget.onChanged?.call((arguments as Map)['value'] as bool);
        _view.currentState?.resync();
      },
    );
  }
}
