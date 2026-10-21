import 'package:flutter/cupertino.dart';

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// An AppKit `NSSwitch`.
///
/// A null [onChanged] disables the switch.
class NativeSwitch extends StatefulWidget {
  const NativeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.controlSize = NativeControlSize.regular,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
    this.fallback,
  });

  final bool value;

  final ValueChanged<bool>? onChanged;

  final NativeControlSize controlSize;

  /// The VoiceOver label. Null keeps AppKit's, which reads the control's
  /// title.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the control (`toolTip`).
  final String? tooltip;

  /// Whether Tab and Full Keyboard Access can focus the control. While it
  /// has focus, key presses go to AppKit instead of Flutter.
  final bool focusable;

  /// Shown when native views are not supported. Defaults to a
  /// [CupertinoSwitch].
  final Widget? fallback;

  @override
  State<NativeSwitch> createState() => _NativeSwitchState();
}

class _NativeSwitchState extends State<NativeSwitch> {
  final _view = GlobalKey<NativeViewState>();

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return widget.fallback ??
          CupertinoSwitch(value: widget.value, onChanged: widget.onChanged);
    }
    final height = estimatedControlHeight(widget.controlSize.index);
    return NativeView(
      key: _view,
      viewType: 'switch',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      focusable: widget.focusable,
      enabled: widget.onChanged != null,
      estimatedSize: Size(height * 1.7, height),
      params: {'value': widget.value, 'controlSize': widget.controlSize.name},
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        widget.onChanged?.call((arguments as Map)['value'] as bool);
        _view.currentState?.resync();
      },
    );
  }
}
