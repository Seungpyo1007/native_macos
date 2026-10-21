import 'package:flutter/cupertino.dart';

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// An AppKit `NSSlider`. It takes the parent's width.
///
/// A null [onChanged] disables the slider.
class NativeSlider extends StatefulWidget {
  const NativeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.tickMarks = 0,
    this.snapToTicks = false,
    this.neutralValue,
    this.prominence = NativeTintProminence.automatic,
    this.controlSize = NativeControlSize.regular,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
    this.fallback,
  }) : assert(min < max),
       assert(tickMarks >= 0);

  final double value;

  /// Called continuously while the knob is dragged.
  final ValueChanged<double>? onChanged;

  /// Called once when the drag ends.
  final ValueChanged<double>? onChangeEnd;

  final double min;

  final double max;

  /// The number of tick marks, or 0 for none.
  final int tickMarks;

  /// Whether the knob stops only on tick marks.
  final bool snapToTicks;

  /// The value the track fill starts from. Needs macOS 26; ignored before
  /// it. Null fills from [min].
  final double? neutralValue;

  final NativeTintProminence prominence;

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
  /// [CupertinoSlider].
  final Widget? fallback;

  @override
  State<NativeSlider> createState() => _NativeSliderState();
}

class _NativeSliderState extends State<NativeSlider> {
  final _view = GlobalKey<NativeViewState>();

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return widget.fallback ??
          CupertinoSlider(
            value: widget.value,
            onChanged: widget.onChanged,
            onChangeEnd: widget.onChangeEnd,
            min: widget.min,
            max: widget.max,
            divisions: widget.snapToTicks && widget.tickMarks > 1
                ? widget.tickMarks - 1
                : null,
          );
    }
    final height = estimatedControlHeight(widget.controlSize.index);
    return NativeView(
      key: _view,
      viewType: 'slider',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      focusable: widget.focusable,
      expand: true,
      enabled: widget.onChanged != null,
      estimatedSize: Size(160, widget.tickMarks > 0 ? height + 6 : height),
      params: {
        'value': widget.value,
        'min': widget.min,
        'max': widget.max,
        'tickMarks': widget.tickMarks,
        'snapToTicks': widget.snapToTicks,
        'neutralValue': widget.neutralValue,
        'prominence': widget.prominence.name,
        'controlSize': widget.controlSize.name,
      },
      onEvent: (method, arguments) {
        final value = ((arguments as Map)['value'] as num).toDouble();
        if (method == 'changed') {
          widget.onChanged?.call(value);
        } else if (method == 'changeEnded') {
          widget.onChangeEnd?.call(value);
          // Resyncing mid-drag would fight the knob, so it waits until here.
          _view.currentState?.resync();
        }
      },
    );
  }
}
