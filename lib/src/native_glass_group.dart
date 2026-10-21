import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'native_glass_container.dart';
import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// Draws the [NativeGlassGroupItem]s below it as one Liquid Glass surface
/// (`NSGlassEffectContainerView`).
///
/// Items closer than [spacing] blend into each other, and an item that moves
/// or resizes morphs instead of jumping, as glass buttons do in macOS 26.
/// The group paints the glass under [child]; the items paint their own
/// children on top and take clicks. Items follow layout and repaints: an
/// item that moves only through a compositing transform, without being
/// painted again, keeps its old glass until the next paint.
///
/// Before macOS 26 each item is a separate `NSVisualEffectView`, without
/// blending. Off macOS only [child] is shown, and each item uses its
/// fallback.
class NativeGlassGroup extends StatefulWidget {
  const NativeGlassGroup({super.key, required this.child, this.spacing = 0})
    : assert(spacing >= 0);

  final Widget child;

  /// How close items get before they start to blend, in logical pixels.
  final double spacing;

  @override
  State<NativeGlassGroup> createState() => _NativeGlassGroupState();
}

/// A glass shape in the nearest [NativeGlassGroup], sized by [child].
///
/// Without a group above it, it behaves like a [NativeGlassContainer].
class NativeGlassGroupItem extends StatelessWidget {
  const NativeGlassGroupItem({
    super.key,
    required this.child,
    this.cornerRadius = 16,
    this.style = NativeGlassStyle.regular,
    this.tint,
    this.fallback,
  });

  final Widget child;

  final double cornerRadius;

  final NativeGlassStyle style;

  /// Tints the glass. Null keeps it neutral.
  final Color? tint;

  /// Builds the surface when native views are not supported. Without it,
  /// [child] is shown as is.
  final Widget Function(BuildContext context, Widget child)? fallback;

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return fallback?.call(context, child) ?? child;
    }
    final group = context
        .dependOnInheritedWidgetOfExactType<_GlassGroupScope>()
        ?.state;
    if (group == null) {
      return NativeGlassContainer(
        cornerRadius: cornerRadius,
        style: style,
        tint: tint,
        child: child,
      );
    }
    return _GlassItem(
      group: group,
      shape: {
        'cornerRadius': cornerRadius,
        'style': style.name,
        'tint': tint?.toARGB32(),
      },
      child: child,
    );
  }
}

class _NativeGlassGroupState extends State<NativeGlassGroup> {
  final _items = <_RenderGlassItem, int>{};
  int _nextId = 0;
  List<Map<String, Object?>> _shapes = const [];
  bool _syncScheduled = false;

  void _attach(_RenderGlassItem item) {
    _items[item] = _nextId++;
    _scheduleSync();
  }

  void _detach(_RenderGlassItem item) {
    _items.remove(item);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Measures every item against the group and sends the shapes when they
  /// changed.
  void _sync() {
    final group = context.findRenderObject();
    if (group is! RenderBox || !group.hasSize) return;
    final shapes = <Map<String, Object?>>[];
    for (final MapEntry(key: item, value: id) in _items.entries) {
      if (!item.attached || !item.hasSize) continue;
      final rect = MatrixUtils.transformRect(
        item.getTransformTo(group),
        Offset.zero & item.size,
      );
      shapes.add({
        'id': id,
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
        ...item.shape,
      });
    }
    if (!deepEquals(shapes, _shapes)) setState(() => _shapes = shapes);
  }

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: NativeView(
              viewType: 'glassGroup',
              fill: true,
              estimatedSize: Size.zero,
              params: {'spacing': widget.spacing, 'shapes': _shapes},
            ),
          ),
        ),
        _GlassGroupScope(state: this, child: widget.child),
      ],
    );
  }
}

class _GlassGroupScope extends InheritedWidget {
  const _GlassGroupScope({required this.state, required super.child});

  final _NativeGlassGroupState state;

  @override
  bool updateShouldNotify(_GlassGroupScope oldWidget) =>
      !identical(state, oldWidget.state);
}

class _GlassItem extends SingleChildRenderObjectWidget {
  const _GlassItem({
    required this.group,
    required this.shape,
    required super.child,
  });

  final _NativeGlassGroupState group;
  final Map<String, Object?> shape;

  @override
  _RenderGlassItem createRenderObject(BuildContext context) =>
      _RenderGlassItem(group, shape);

  @override
  void updateRenderObject(BuildContext context, _RenderGlassItem render) {
    render
      ..group = group
      ..shape = shape;
  }
}

/// Tells the group to measure again whenever it is laid out or painted.
class _RenderGlassItem extends RenderProxyBox {
  _RenderGlassItem(this._group, this._shape);

  _NativeGlassGroupState _group;
  set group(_NativeGlassGroupState value) {
    if (identical(value, _group)) return;
    if (attached) _group._detach(this);
    _group = value;
    if (attached) _group._attach(this);
  }

  Map<String, Object?> _shape;
  Map<String, Object?> get shape => _shape;
  set shape(Map<String, Object?> value) {
    if (deepEquals(value, _shape)) return;
    _shape = value;
    _group._scheduleSync();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _group._attach(this);
  }

  @override
  void detach() {
    _group._detach(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _group._scheduleSync();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _group._scheduleSync();
  }
}
