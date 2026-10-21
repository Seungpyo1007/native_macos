import 'package:flutter/cupertino.dart';

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// An AppKit checkbox (`NSButton` with the checkbox type) with an optional
/// label.
///
/// A null [onChanged] disables the checkbox.
class NativeCheckbox extends StatefulWidget {
  const NativeCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.controlSize = NativeControlSize.regular,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
    this.fallback,
  });

  final bool value;

  final ValueChanged<bool>? onChanged;

  /// Shown next to the box. Clicking it toggles the box too.
  final String? label;

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
  /// [CupertinoCheckbox] followed by [label].
  final Widget? fallback;

  @override
  State<NativeCheckbox> createState() => _NativeCheckboxState();
}

class _NativeCheckboxState extends State<NativeCheckbox> {
  final _view = GlobalKey<NativeViewState>();

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      if (widget.fallback case final fallback?) return fallback;
      final box = CupertinoCheckbox(
        value: widget.value,
        onChanged: widget.onChanged == null
            ? null
            : (value) => widget.onChanged!(value ?? false),
      );
      if (widget.label == null) return box;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [box, Text(widget.label!)],
      );
    }
    final label = widget.label ?? '';
    return NativeView(
      key: _view,
      viewType: 'checkbox',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      focusable: widget.focusable,
      enabled: widget.onChanged != null,
      estimatedSize: Size(
        label.isEmpty ? 18 : estimatedTextWidth(label, padding: 22),
        estimatedControlHeight(widget.controlSize.index) - 4,
      ),
      params: {
        'value': widget.value,
        'label': label,
        'controlSize': widget.controlSize.name,
      },
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        widget.onChanged?.call((arguments as Map)['value'] as bool);
        _view.currentState?.resync();
      },
    );
  }
}
