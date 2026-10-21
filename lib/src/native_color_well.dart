import 'package:flutter/cupertino.dart';

import 'native_support.dart';
import 'native_view.dart';

/// How a [NativeColorWell] looks (`NSColorWell.Style`). Needs macOS 13;
/// every style is [standard] before it.
enum NativeColorWellStyle {
  /// A swatch that opens the color panel.
  standard,

  /// A swatch that opens a popover of colors.
  minimal,

  /// A swatch with a separate button for the color panel.
  expanded,
}

/// An AppKit `NSColorWell` that opens the system color picker.
///
/// [onChanged] is called continuously while a color is picked. A null
/// [onChanged] disables the well.
class NativeColorWell extends StatefulWidget {
  const NativeColorWell({
    super.key,
    required this.value,
    required this.onChanged,
    this.style = NativeColorWellStyle.standard,
    this.supportsAlpha = true,
    this.semanticsLabel,
    this.tooltip,
    this.fallback,
  });

  final Color value;

  final ValueChanged<Color>? onChanged;

  final NativeColorWellStyle style;

  /// Whether the picker offers opacity. The panel hides it from macOS 14;
  /// before it, colors are made opaque.
  final bool supportsAlpha;

  /// The VoiceOver label. Null keeps AppKit's.
  final String? semanticsLabel;

  /// Shown when the pointer rests on the well (`toolTip`).
  final String? tooltip;

  /// Shown when native views are not supported. Defaults to a swatch of
  /// [value] that cannot change it.
  final Widget? fallback;

  @override
  State<NativeColorWell> createState() => _NativeColorWellState();
}

class _NativeColorWellState extends State<NativeColorWell> {
  final _view = GlobalKey<NativeViewState>();

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return widget.fallback ??
          Container(
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: widget.value,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: CupertinoColors.separator),
            ),
          );
    }
    return NativeView(
      key: _view,
      viewType: 'colorWell',
      semanticsLabel: widget.semanticsLabel,
      tooltip: widget.tooltip,
      enabled: widget.onChanged != null,
      estimatedSize: Size(
        widget.style == NativeColorWellStyle.expanded ? 64 : 44,
        24,
      ),
      params: {
        'value': widget.value.toARGB32(),
        'style': widget.style.name,
        'supportsAlpha': widget.supportsAlpha,
      },
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        widget.onChanged?.call(Color((arguments as Map)['value'] as int));
        _view.currentState?.resync();
      },
    );
  }
}
