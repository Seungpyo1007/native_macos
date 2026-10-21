import 'package:flutter/cupertino.dart';

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// An AppKit `NSStepper`: up and down arrows that change [value] by [step].
///
/// A null [onChanged] disables it. Pair it with a label that shows the
/// value.
class NativeStepper extends StatefulWidget {
  const NativeStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.wraps = false,
    this.autorepeat = true,
    this.controlSize = NativeControlSize.regular,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
    this.fallback,
  }) : assert(min <= max),
       assert(step > 0);

  final double value;

  final ValueChanged<double>? onChanged;

  final double min;

  final double max;

  final double step;

  /// Whether going past [max] starts again at [min], and the other way.
  final bool wraps;

  /// Whether holding an arrow keeps changing the value.
  final bool autorepeat;

  final NativeControlSize controlSize;

  /// The VoiceOver label. Null keeps AppKit's.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the stepper (`toolTip`).
  final String? tooltip;

  /// Whether Tab and Full Keyboard Access can focus the stepper. While it
  /// has focus, key presses go to AppKit instead of Flutter.
  final bool focusable;

  /// Shown when native views are not supported. Defaults to minus and plus
  /// [CupertinoButton]s.
  final Widget? fallback;

  @override
  State<NativeStepper> createState() => _NativeStepperState();
}

class _NativeStepperState extends State<NativeStepper> {
  final _view = GlobalKey<NativeViewState>();

  double _next(double delta) {
    final next = widget.value + delta;
    if (next > widget.max) return widget.wraps ? widget.min : widget.max;
    if (next < widget.min) return widget.wraps ? widget.max : widget.min;
    return next;
  }

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      if (widget.fallback case final fallback?) return fallback;
      final onChanged = widget.onChanged;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: onChanged == null
                ? null
                : () => onChanged(_next(-widget.step)),
            child: const Icon(CupertinoIcons.minus, size: 16),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: onChanged == null
                ? null
                : () => onChanged(_next(widget.step)),
            child: const Icon(CupertinoIcons.plus, size: 16),
          ),
        ],
      );
    }
    final height = estimatedControlHeight(widget.controlSize.index);
    return NativeView(
      key: _view,
      viewType: 'stepper',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      focusable: widget.focusable,
      enabled: widget.onChanged != null,
      estimatedSize: Size(height * 0.65, height),
      params: {
        'value': widget.value,
        'min': widget.min,
        'max': widget.max,
        'step': widget.step,
        'wraps': widget.wraps,
        'autorepeat': widget.autorepeat,
        'controlSize': widget.controlSize.name,
      },
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        widget.onChanged?.call(((arguments as Map)['value'] as num).toDouble());
        _view.currentState?.resync();
      },
    );
  }
}
