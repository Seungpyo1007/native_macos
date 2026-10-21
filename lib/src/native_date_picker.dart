import 'package:flutter/cupertino.dart';

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// How a [NativeDatePicker] looks (`NSDatePicker.Style`).
enum NativeDatePickerStyle {
  /// A text field with a stepper, as in System Settings.
  textFieldAndStepper,

  /// A text field alone.
  textField,

  /// A calendar, or a clock for times (`clockAndCalendar`).
  graphical,
}

/// What a [NativeDatePicker] edits.
enum NativeDatePickerElements { date, time, dateAndTime }

/// An AppKit `NSDatePicker`.
///
/// Dates are shown in the user's time zone. A null [onChanged] disables
/// the picker. The text field styles need keyboard focus to edit, so
/// [focusable] is true by default; clicking Flutter content afterwards gives
/// the keys back to Flutter.
class NativeDatePicker extends StatefulWidget {
  const NativeDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.style = NativeDatePickerStyle.textFieldAndStepper,
    this.elements = NativeDatePickerElements.date,
    this.min,
    this.max,
    this.controlSize = NativeControlSize.regular,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = true,
    this.fallback,
  });

  final DateTime value;

  final ValueChanged<DateTime>? onChanged;

  final NativeDatePickerStyle style;

  final NativeDatePickerElements elements;

  /// The earliest date the picker allows. Null has no limit.
  final DateTime? min;

  /// The latest date the picker allows. Null has no limit.
  final DateTime? max;

  final NativeControlSize controlSize;

  /// The VoiceOver label. Null keeps AppKit's.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the picker (`toolTip`).
  final String? tooltip;

  /// Whether Tab, Full Keyboard Access, and clicks can focus the picker.
  final bool focusable;

  /// Shown when native views are not supported. Defaults to a button that
  /// opens a [CupertinoDatePicker].
  final Widget? fallback;

  @override
  State<NativeDatePicker> createState() => _NativeDatePickerState();
}

class _NativeDatePickerState extends State<NativeDatePicker> {
  final _view = GlobalKey<NativeViewState>();

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return widget.fallback ?? _fallback(context);
    }
    final graphical = widget.style == NativeDatePickerStyle.graphical;
    final height = estimatedControlHeight(widget.controlSize.index);
    final estimate = graphical
        ? (widget.elements == NativeDatePickerElements.dateAndTime
              ? const Size(278, 148)
              : const Size(139, 148))
        : Size(switch (widget.elements) {
            NativeDatePickerElements.date => 100,
            NativeDatePickerElements.time => 80,
            NativeDatePickerElements.dateAndTime => 170,
          }, height);
    return NativeView(
      key: _view,
      viewType: 'datePicker',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      focusable: widget.focusable,
      enabled: widget.onChanged != null,
      estimatedSize: estimate,
      params: {
        'value': widget.value.millisecondsSinceEpoch,
        'min': widget.min?.millisecondsSinceEpoch,
        'max': widget.max?.millisecondsSinceEpoch,
        'style': widget.style.name,
        'elements': widget.elements.name,
        'controlSize': widget.controlSize.name,
      },
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        final ms = ((arguments as Map)['value'] as num).round();
        widget.onChanged?.call(DateTime.fromMillisecondsSinceEpoch(ms));
        _view.currentState?.resync();
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final onChanged = widget.onChanged;
    final v = widget.value;
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${v.year}-${two(v.month)}-${two(v.day)}';
    final time = '${two(v.hour)}:${two(v.minute)}';
    final text = switch (widget.elements) {
      NativeDatePickerElements.date => date,
      NativeDatePickerElements.time => time,
      NativeDatePickerElements.dateAndTime => '$date $time',
    };
    return CupertinoButton(
      onPressed: onChanged == null
          ? null
          : () => showCupertinoModalPopup<void>(
              context: context,
              builder: (context) => Container(
                height: 260,
                color: CupertinoColors.systemBackground.resolveFrom(context),
                child: CupertinoDatePicker(
                  initialDateTime: v,
                  minimumDate: widget.min,
                  maximumDate: widget.max,
                  mode: switch (widget.elements) {
                    NativeDatePickerElements.date =>
                      CupertinoDatePickerMode.date,
                    NativeDatePickerElements.time =>
                      CupertinoDatePickerMode.time,
                    NativeDatePickerElements.dateAndTime =>
                      CupertinoDatePickerMode.dateAndTime,
                  },
                  onDateTimeChanged: onChanged,
                ),
              ),
            ),
      child: Text(text),
    );
  }
}
