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
    this.borderShape = NativeBorderShape.automatic,
    this.controlSize = NativeControlSize.regular,
    this.tint,
    this.expand = false,
    this.fallback,
  });

  final List<String> labels;

  /// The selected segment, or -1 for none.
  final int selectedIndex;

  final ValueChanged<int>? onChanged;

  final NativeBorderShape borderShape;

  final NativeControlSize controlSize;

  /// The selected segment's color. Null uses the user's accent color.
  final Color? tint;

  /// Takes the parent's width instead of the native fitting width.
  final bool expand;

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
    final width = widget.labels.fold<double>(
      0,
      (sum, label) => sum + estimatedTextWidth(label, padding: 20),
    );
    return NativeView(
      key: _view,
      viewType: 'segmented',
      expand: widget.expand,
      enabled: widget.onChanged != null,
      tint: widget.tint,
      estimatedSize: Size(
        width,
        estimatedControlHeight(widget.controlSize.index),
      ),
      params: {
        'labels': widget.labels,
        'selectedIndex': widget.selectedIndex,
        'borderShape': widget.borderShape.name,
        'controlSize': widget.controlSize.name,
        'expand': widget.expand,
      },
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        widget.onChanged?.call((arguments as Map)['value'] as int);
        _view.currentState?.resync();
      },
    );
  }
}
