import 'package:flutter/widgets.dart';

import 'native_support.dart';
import 'native_view.dart';

/// How a [NativeSidebar] draws its background.
enum NativeSidebarStyle {
  /// A floating Liquid Glass panel on macOS 26 and later, inset from the
  /// window edges; the sidebar material before.
  automatic,

  /// Always the sidebar material (`NSVisualEffectView.Material.sidebar`),
  /// which shows a blur of the desktop behind the window.
  material,
}

/// A sidebar with a native background next to [child], like Finder's or
/// Mail's.
///
/// [sidebar] is Flutter content painted on the native background. With
/// [NativeSidebarStyle.automatic] on macOS 26, the background is a glass
/// panel inset by [glassInset], and [sidebar] is padded by the same amount
/// so it stays on the panel. A [resizable] sidebar has a drag handle on its
/// trailing edge between [minWidth] and [maxWidth].
class NativeSidebar extends StatefulWidget {
  const NativeSidebar({
    super.key,
    required this.sidebar,
    required this.child,
    this.width = 220,
    this.style = NativeSidebarStyle.automatic,
    this.glassInset = 8,
    this.cornerRadius = 12,
    this.resizable = false,
    this.minWidth = 160,
    this.maxWidth = 360,
    this.onWidthChanged,
    this.fallback,
  }) : assert(minWidth <= maxWidth);

  final Widget sidebar;

  final Widget child;

  /// The sidebar's width. When [resizable], the starting width; a parent
  /// that stores [onWidthChanged] values can pass them back here.
  final double width;

  final NativeSidebarStyle style;

  /// The margin around the glass panel on macOS 26.
  final double glassInset;

  /// The glass panel's corner radius on macOS 26.
  final double cornerRadius;

  final bool resizable;

  final double minWidth;

  final double maxWidth;

  /// Called while the sidebar is resized.
  final ValueChanged<double>? onWidthChanged;

  /// Builds the sidebar background when native views are not supported.
  /// Without it, [sidebar] is shown on no background.
  final Widget Function(BuildContext context, Widget sidebar)? fallback;

  @override
  State<NativeSidebar> createState() => _NativeSidebarState();
}

class _NativeSidebarState extends State<NativeSidebar> {
  late double _width = widget.width;

  @override
  void initState() {
    super.initState();
    // The padding depends on whether glass is drawn, which the native side
    // answers.
    NativeMacos.loadCapabilities().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(NativeSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.width != oldWidget.width) _width = widget.width;
  }

  @override
  Widget build(BuildContext context) {
    final width = _width.clamp(widget.minWidth, widget.maxWidth);
    Widget panel;
    if (!NativeMacos.isSupported) {
      panel = widget.fallback?.call(context, widget.sidebar) ?? widget.sidebar;
    } else {
      final glass =
          widget.style == NativeSidebarStyle.automatic &&
          NativeMacos.hasLiquidGlass;
      panel = Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: NativeView(
              viewType: 'sidebar',
              fill: true,
              estimatedSize: Size.zero,
              params: {
                'style': widget.style.name,
                'inset': widget.glassInset,
                'cornerRadius': widget.cornerRadius,
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(glass ? widget.glassInset : 0),
            child: widget.sidebar,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: width, child: panel),
        if (widget.resizable)
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                final rtl =
                    Directionality.maybeOf(context) == TextDirection.rtl;
                final next = (_width + (rtl ? -1 : 1) * details.delta.dx).clamp(
                  widget.minWidth,
                  widget.maxWidth,
                );
                if (next == _width) return;
                setState(() => _width = next);
                widget.onWidthChanged?.call(next);
              },
              child: const SizedBox(width: 6),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
