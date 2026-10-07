import 'package:flutter/widgets.dart';

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// A Liquid Glass surface drawn by AppKit, sized by [child] and painted under
/// it.
///
/// On macOS 26 and later this is an `NSGlassEffectView`, which refracts the
/// Flutter content behind it. Earlier versions get an `NSVisualEffectView`.
/// The glass never takes clicks: [child] gets them.
///
/// Glass belongs to the control and navigation layer (toolbars, sidebars,
/// floating buttons), not to content.
class NativeGlassContainer extends StatelessWidget {
  const NativeGlassContainer({
    super.key,
    required this.child,
    this.cornerRadius = 16,
    this.style = NativeGlassStyle.regular,
    this.tint,
    this.interactive = false,
    this.fallback,
  });

  final Widget child;

  final double cornerRadius;

  final NativeGlassStyle style;

  /// Tints the glass. Null keeps it neutral.
  final Color? tint;

  /// Whether the glass reacts to the pointer (`effectIsInteractive`). Needs
  /// macOS 27; ignored before it.
  final bool interactive;

  /// Builds the surface when native views are not supported. Without it,
  /// [child] is shown as is.
  final Widget Function(BuildContext context, Widget child)? fallback;

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return fallback?.call(context, child) ?? child;
    }
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: NativeView(
              viewType: 'glass',
              fill: true,
              estimatedSize: Size.zero,
              tint: tint,
              params: {
                'cornerRadius': cornerRadius,
                'style': style.name,
                'glassInteractive': interactive,
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}
