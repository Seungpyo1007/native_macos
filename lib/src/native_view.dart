import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'native_channel.dart';
import 'native_input_blocker.dart';
import 'native_support.dart';

/// Hosts one AppKit view and keeps it in sync with the widget.
///
/// Every update sends the whole configuration ([params] plus the shared keys
/// below), and nothing is sent when it has not changed. The native side
/// reports its fitting size, which replaces [estimatedSize] after the first
/// frame.
class NativeView extends StatefulWidget {
  const NativeView({
    super.key,
    required this.viewType,
    required this.params,
    required this.estimatedSize,
    this.onEvent,
    this.expand = false,
    this.fill = false,
    this.tint,
    this.enabled = true,
    this.semanticsLabel,
    this.tooltip,
    this.focusable = false,
  });

  /// The id after `native_macos/`, such as `button`.
  final String viewType;

  final Map<String, Object?> params;

  /// The size used until the native view reports its own.
  final Size estimatedSize;

  /// Native events such as `pressed` or `changed`, with their arguments.
  final void Function(String method, Object? arguments)? onEvent;

  /// Takes the parent's width instead of the native fitting width.
  final bool expand;

  /// Fills the parent in both directions and ignores the native size.
  final bool fill;

  /// Null uses the user's accent color.
  final Color? tint;

  final bool enabled;

  /// The VoiceOver label of the AppKit control. Null keeps AppKit's own,
  /// which is usually the control's title.
  final String? semanticsLabel;

  /// The control's help tag (`NSView.toolTip`).
  final String? tooltip;

  /// Whether the control can become the key view, so Tab and Full Keyboard
  /// Access reach it. While it has focus, key presses go to AppKit instead of
  /// Flutter.
  final bool focusable;

  @override
  State<NativeView> createState() => NativeViewState();
}

class NativeViewState extends State<NativeView> {
  static int _nextChannel = 0;

  // The session keeps names unique across hot restarts, which start the
  // count again while the previous run's native views may still be alive.
  late final MethodChannel _channel = MethodChannel(
    'native_macos/view_${nativeSession}_${_nextChannel++}',
  );
  Map<String, Object?>? _lastSent;
  Map<String, Object?>? _creationParams;
  Size? _nativeSize;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    // The handler is set before the view exists, so the first size report
    // cannot arrive before anyone listens for it.
    _channel.setMethodCallHandler(_onNativeCall);
    NativeMacos.loadCapabilities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sendIfChanged();
  }

  @override
  void didUpdateWidget(NativeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sendIfChanged();
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Map<String, Object?> _snapshot() {
    final brightness = nativeBrightness(context);
    return {
      ...widget.params,
      'channel': _channel.name,
      'brightness': brightness.name,
      // AppKitView does not pass the layout direction to the native view.
      'rtl': Directionality.maybeOf(context) == TextDirection.rtl,
      'tint': widget.tint?.toARGB32(),
      'enabled': widget.enabled,
      'interactive': !NativeInputBlocker.isBlocked(context),
      'semanticsLabel': widget.semanticsLabel,
      'tooltip': widget.tooltip,
      'focusable': widget.focusable,
    };
  }

  void _sendIfChanged() {
    // Before the view exists, the creation params carry the first build and
    // [_onCreated] sends whatever changed since.
    if (!_created) return;
    final next = _snapshot();
    if (_lastSent != null && deepEquals(_lastSent, next)) return;
    _lastSent = next;
    _update(next);
  }

  void _update(Map<String, Object?> snapshot) {
    _channel.invokeMethod<void>('update', snapshot).catchError((
      Object error,
      StackTrace stack,
    ) {
      // A missing plugin or a native failure must not become an unhandled
      // async error; the view keeps its previous configuration.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'native_macos',
          context: ErrorDescription(
            'while updating a native ${widget.viewType}',
          ),
        ),
      );
    });
  }

  /// Sends the configuration again after the next frame, even when it has not
  /// changed.
  ///
  /// AppKit changes a control's state as soon as it is clicked. If the parent
  /// does not rebuild with the new value, this puts the old one back, so the
  /// widget stays controlled by Dart.
  void resync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_created) return;
      _update(_lastSent = _snapshot());
    });
    // A post-frame callback does not ask for a frame by itself.
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<Object?> _onNativeCall(MethodCall call) async {
    if (!mounted) return null;
    if (call.method == 'size') {
      final args = call.arguments as Map;
      final size = Size(
        (args['width'] as num).toDouble(),
        (args['height'] as num).toDouble(),
      );
      // Sliders and bars report no width; their width comes from the parent.
      if (size != _nativeSize && size.height > 0) {
        setState(() => _nativeSize = size);
      }
      return null;
    }
    widget.onEvent?.call(call.method, call.arguments);
    return null;
  }

  void _onCreated(int id) {
    _created = true;
    // The view was created with the configuration from its first build.
    // Anything that changed while it was being created goes out now.
    _lastSent = _creationParams;
    _sendIfChanged();
  }

  @override
  Widget build(BuildContext context) {
    _creationParams ??= _snapshot();
    final view = AppKitView(
      viewType: 'native_macos/${widget.viewType}',
      layoutDirection: Directionality.maybeOf(context),
      creationParams: _creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onCreated,
    );
    if (widget.fill) return view;
    final native = _nativeSize;
    final height = native?.height ?? widget.estimatedSize.height;
    final fitting = native != null && native.width > 0
        ? native.width
        : widget.estimatedSize.width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = widget.expand && constraints.hasBoundedWidth
            ? constraints.maxWidth
            : fitting;
        return SizedBox(width: width, height: height, child: view);
      },
    );
  }
}

/// The height AppKit uses for a bezeled control at each size, used until the
/// native view reports its fitting size.
double estimatedControlHeight(int sizeIndex) =>
    const [16.0, 20.0, 24.0, 30.0, 36.0][sizeIndex];

/// The width of [text] in the system font, plus [padding].
double estimatedTextWidth(String text, {double padding = 24}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 13)),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width + padding;
  painter.dispose();
  return width;
}

/// The app's brightness, which native views follow instead of the system's.
Brightness nativeBrightness(BuildContext context) =>
    CupertinoTheme.maybeBrightnessOf(context) ??
    MediaQuery.maybePlatformBrightnessOf(context) ??
    Brightness.light;

/// Compares maps and lists by content, so rebuilt but equal settings are not
/// sent again.
bool deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
