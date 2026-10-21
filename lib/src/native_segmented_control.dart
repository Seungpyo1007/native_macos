import 'package:flutter/cupertino.dart';

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// An AppKit `NSSegmentedControl` that selects one segment.
///
/// A null [onChanged] disables the control.
class NativeSegmentedControl extends StatefulWidget {
  const NativeSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.symbols,
    this.segmentTooltips,
    this.borderShape = NativeBorderShape.automatic,
    this.controlSize = NativeControlSize.regular,
    this.tint,
    this.expand = false,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
    this.fallback,
  });

  final List<String> labels;

  /// The selected segment, or -1 for none.
  final int selectedIndex;

  final ValueChanged<int>? onChanged;

  /// One SF Symbol name per segment, shown instead of the labels. The labels
  /// stay the segments' VoiceOver descriptions.
  final List<String>? symbols;

  /// One help tag per segment.
  final List<String>? segmentTooltips;

  final NativeBorderShape borderShape;

  final NativeControlSize controlSize;

  /// The selected segment's color. Null uses the user's accent color.
  final Color? tint;

  /// Takes the parent's width instead of the native fitting width.
  final bool expand;

  /// The VoiceOver label. Null keeps AppKit's, which reads the control's
  /// title.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the control (`toolTip`).
  final String? tooltip;

  /// Whether Tab and Full Keyboard Access can focus the control. While it
  /// has focus, key presses go to AppKit instead of Flutter.
  final bool focusable;

  /// Shown when native views are not supported. Defaults to a
  /// [CupertinoSlidingSegmentedControl].
  final Widget? fallback;

  @override
  State<NativeSegmentedControl> createState() => _NativeSegmentedControlState();
}

class _NativeSegmentedControlState extends State<NativeSegmentedControl> {
  final _view = GlobalKey<NativeViewState>();

  @override
  Widget build(BuildContext context) {
    assert(
      widget.selectedIndex >= -1 && widget.selectedIndex < widget.labels.length,
      'selectedIndex ${widget.selectedIndex} is out of range for '
      '${widget.labels.length} labels',
    );
    if (!NativeMacos.isSupported) {
      return widget.fallback ??
          CupertinoSlidingSegmentedControl<int>(
            groupValue: widget.selectedIndex < 0 ? null : widget.selectedIndex,
            onValueChanged: (index) {
              if (index != null) widget.onChanged?.call(index);
            },
            children: {
              for (final (i, label) in widget.labels.indexed) i: Text(label),
            },
          );
    }
    return NativeView(
      key: _view,
      viewType: 'segmented',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      focusable: widget.focusable,
      expand: widget.expand,
      enabled: widget.onChanged != null,
      tint: widget.tint,
      estimatedSize: _estimate(
        widget.labels,
        widget.symbols,
        widget.controlSize,
      ),
      params: {
        ..._segmentParams(
          labels: widget.labels,
          symbols: widget.symbols,
          tooltips: widget.segmentTooltips,
          borderShape: widget.borderShape,
          controlSize: widget.controlSize,
          expand: widget.expand,
        ),
        'mode': 'selectOne',
        'selectedIndex': widget.selectedIndex,
      },
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        widget.onChanged?.call((arguments as Map)['value'] as int);
        _view.currentState?.resync();
      },
    );
  }
}

Size _estimate(
  List<String> labels,
  List<String>? symbols,
  NativeControlSize controlSize,
) {
  final width = symbols != null
      ? labels.length * 32.0
      : labels.fold<double>(
          0,
          (sum, label) => sum + estimatedTextWidth(label, padding: 20),
        );
  return Size(width, estimatedControlHeight(controlSize.index));
}

Map<String, Object?> _segmentParams({
  required List<String> labels,
  required List<String>? symbols,
  required List<String>? tooltips,
  required NativeBorderShape borderShape,
  required NativeControlSize controlSize,
  required bool expand,
}) {
  assert(symbols == null || symbols.length == labels.length);
  assert(tooltips == null || tooltips.length == labels.length);
  return {
    'labels': labels,
    'symbols': symbols,
    'segmentTooltips': tooltips,
    'borderShape': borderShape.name,
    'controlSize': controlSize.name,
    'expand': expand,
  };
}

/// An AppKit `NSSegmentedControl` whose segments act as buttons that do not
/// stay selected (`momentary`), such as back and forward.
///
/// A null [onPressed] disables the control.
class NativeSegmentedButtons extends StatelessWidget {
  const NativeSegmentedButtons({
    super.key,
    required this.labels,
    required this.onPressed,
    this.symbols,
    this.segmentTooltips,
    this.borderShape = NativeBorderShape.automatic,
    this.controlSize = NativeControlSize.regular,
    this.expand = false,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
    this.fallback,
  });

  final List<String> labels;

  /// Called with the index of the pressed segment.
  final ValueChanged<int>? onPressed;

  /// One SF Symbol name per segment, shown instead of the labels.
  final List<String>? symbols;

  /// One help tag per segment.
  final List<String>? segmentTooltips;

  final NativeBorderShape borderShape;

  final NativeControlSize controlSize;

  /// Takes the parent's width instead of the native fitting width.
  final bool expand;

  /// The VoiceOver label of the whole control.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the control (`toolTip`).
  final String? tooltip;

  /// Whether Tab and Full Keyboard Access can focus the control.
  final bool focusable;

  /// Shown when native views are not supported. Defaults to a row of
  /// [CupertinoButton]s.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      final onPressed = this.onPressed;
      return fallback ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, label) in labels.indexed)
                CupertinoButton(
                  onPressed: onPressed == null ? null : () => onPressed(i),
                  child: Text(label),
                ),
            ],
          );
    }
    return NativeView(
      viewType: 'segmented',
      semanticsLabel: semanticsLabel,
      tooltip: tooltip,
      focusable: focusable,
      expand: expand,
      enabled: onPressed != null,
      estimatedSize: _estimate(labels, symbols, controlSize),
      params: {
        ..._segmentParams(
          labels: labels,
          symbols: symbols,
          tooltips: segmentTooltips,
          borderShape: borderShape,
          controlSize: controlSize,
          expand: expand,
        ),
        'mode': 'momentary',
      },
      onEvent: (method, arguments) {
        if (method != 'pressed') return;
        final index = (arguments as Map)['value'] as int;
        if (index >= 0) onPressed?.call(index);
      },
    );
  }
}

/// An AppKit `NSSegmentedControl` where any number of segments can be on
/// (`selectAny`), such as bold, italic, and underline.
///
/// A null [onChanged] disables the control.
class NativeMultiSegmentedControl extends StatefulWidget {
  const NativeMultiSegmentedControl({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.symbols,
    this.segmentTooltips,
    this.borderShape = NativeBorderShape.automatic,
    this.controlSize = NativeControlSize.regular,
    this.tint,
    this.expand = false,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
    this.fallback,
  });

  final List<String> labels;

  /// The indices of the segments that are on.
  final Set<int> selected;

  /// Called with the indices that are on after a click.
  final ValueChanged<Set<int>>? onChanged;

  /// One SF Symbol name per segment, shown instead of the labels.
  final List<String>? symbols;

  /// One help tag per segment.
  final List<String>? segmentTooltips;

  final NativeBorderShape borderShape;

  final NativeControlSize controlSize;

  /// The color of segments that are on. Null uses the user's accent color.
  final Color? tint;

  /// Takes the parent's width instead of the native fitting width.
  final bool expand;

  /// The VoiceOver label of the whole control.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the control (`toolTip`).
  final String? tooltip;

  /// Whether Tab and Full Keyboard Access can focus the control.
  final bool focusable;

  /// Shown when native views are not supported. Defaults to a row of
  /// [CupertinoCheckbox]es with labels.
  final Widget? fallback;

  @override
  State<NativeMultiSegmentedControl> createState() =>
      _NativeMultiSegmentedControlState();
}

class _NativeMultiSegmentedControlState
    extends State<NativeMultiSegmentedControl> {
  final _view = GlobalKey<NativeViewState>();

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      final onChanged = widget.onChanged;
      return widget.fallback ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, label) in widget.labels.indexed) ...[
                CupertinoCheckbox(
                  value: widget.selected.contains(i),
                  onChanged: onChanged == null
                      ? null
                      : (on) => onChanged(
                          on == true
                              ? {...widget.selected, i}
                              : ({...widget.selected}..remove(i)),
                        ),
                ),
                Text(label),
              ],
            ],
          );
    }
    final selected = widget.selected.toList()..sort();
    return NativeView(
      key: _view,
      viewType: 'segmented',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      focusable: widget.focusable,
      expand: widget.expand,
      enabled: widget.onChanged != null,
      tint: widget.tint,
      estimatedSize: _estimate(
        widget.labels,
        widget.symbols,
        widget.controlSize,
      ),
      params: {
        ..._segmentParams(
          labels: widget.labels,
          symbols: widget.symbols,
          tooltips: widget.segmentTooltips,
          borderShape: widget.borderShape,
          controlSize: widget.controlSize,
          expand: widget.expand,
        ),
        'mode': 'selectAny',
        'selected': selected,
      },
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        final value = ((arguments as Map)['value'] as List).cast<int>();
        widget.onChanged?.call(value.toSet());
        _view.currentState?.resync();
      },
    );
  }
}
