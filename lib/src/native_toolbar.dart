import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'native_menu.dart';
import 'native_support.dart';
import 'native_view.dart';

/// Where the window title goes relative to the toolbar
/// (`NSWindow.ToolbarStyle`).
enum NativeToolbarStyle {
  /// AppKit decides from the window's configuration.
  automatic,

  /// The title sits above the toolbar.
  expanded,

  /// The title sits inline with the toolbar items.
  unified,

  /// Like [unified], with smaller margins.
  unifiedCompact,
}

/// An item in a [NativeToolbar].
sealed class NativeToolbarItem {
  const NativeToolbarItem();

  Map<String, Object?> _encode();
}

/// A badge on a [NativeToolbarButton] (`NSItemBadge`). Needs macOS 26;
/// ignored before it.
final class NativeToolbarBadge {
  /// A number, such as unread messages.
  const NativeToolbarBadge.count(int this.count) : text = null, _dot = false;

  /// A short text, such as `New`.
  const NativeToolbarBadge.text(String this.text) : count = null, _dot = false;

  /// A dot without content.
  const NativeToolbarBadge.indicator() : count = null, text = null, _dot = true;

  final int? count;
  final String? text;
  final bool _dot;

  Map<String, Object?> _encode() => {
    'count': count,
    'text': text,
    'indicator': _dot,
  };
}

/// A toolbar button (`NSToolbarItem`).
///
/// A null [onPressed] disables it.
final class NativeToolbarButton extends NativeToolbarItem {
  const NativeToolbarButton({
    required this.id,
    required this.label,
    required this.onPressed,
    this.symbol,
    this.tooltip,
    this.prominent = false,
    this.tint,
    this.badge,
  });

  /// Identifies the item across rebuilds. Unique within the toolbar.
  final String id;

  /// Shown under the icon in text display modes, and as the title when
  /// there is no [symbol].
  final String label;

  final VoidCallback? onPressed;

  /// An SF Symbol name.
  final String? symbol;

  final String? tooltip;

  /// Draws the button like a "Done" button (`NSToolbarItem.Style
  /// .prominent`). Needs macOS 26; ignored before it.
  final bool prominent;

  /// The background tint of a prominent button. Needs macOS 26.
  final Color? tint;

  final NativeToolbarBadge? badge;

  @override
  Map<String, Object?> _encode() => {
    'kind': 'button',
    'id': id,
    'label': label,
    'symbol': symbol,
    'tooltip': tooltip,
    'enabled': onPressed != null,
    'prominent': prominent,
    'tint': tint?.toARGB32(),
    'badge': badge?._encode(),
  };
}

/// Segments that select one option (`NSToolbarItemGroup`), such as view
/// modes.
///
/// A null [onChanged] disables them.
final class NativeToolbarSegments extends NativeToolbarItem {
  const NativeToolbarSegments({
    required this.id,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.symbols,
  }) : assert(symbols == null || symbols.length == labels.length);

  final String id;

  /// One label per segment, shown when there is no symbol.
  final List<String> labels;

  /// One SF Symbol name per segment, shown instead of the labels.
  final List<String>? symbols;

  final int selectedIndex;

  final ValueChanged<int>? onChanged;

  @override
  Map<String, Object?> _encode() => {
    'kind': 'segments',
    'id': id,
    'labels': labels,
    'symbols': symbols,
    'selectedIndex': selectedIndex,
    'enabled': onChanged != null,
  };
}

/// A toolbar button that opens a menu (`NSMenuToolbarItem`).
final class NativeToolbarMenu<T> extends NativeToolbarItem {
  const NativeToolbarMenu({
    required this.id,
    required this.label,
    required this.items,
    required this.onSelected,
    this.symbol,
  });

  final String id;

  final String label;

  final List<NativeMenuEntry<T>> items;

  final ValueChanged<T>? onSelected;

  final String? symbol;

  void _select(Object? index) {
    final value = menuValueAt(items, index);
    if (value is T) onSelected?.call(value);
  }

  @override
  Map<String, Object?> _encode() => {
    'kind': 'menu',
    'id': id,
    'label': label,
    'symbol': symbol,
    'items': encodeMenuEntries(items),
    'enabled': onSelected != null,
  };
}

/// A search field that expands from a toolbar button
/// (`NSSearchToolbarItem`).
///
/// The field keeps its own text: [onChanged] reports each edit and
/// [onSubmitted] reports Return.
final class NativeToolbarSearch extends NativeToolbarItem {
  const NativeToolbarSearch({
    required this.id,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
  });

  final String id;

  final String? placeholder;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  @override
  Map<String, Object?> _encode() => {
    'kind': 'search',
    'id': id,
    'placeholder': placeholder,
  };
}

/// Empty space between items.
final class NativeToolbarSpace extends NativeToolbarItem {
  /// Space that grows to push the next items to the trailing edge.
  const NativeToolbarSpace.flexible() : _flexible = true;

  /// A fixed gap.
  const NativeToolbarSpace.fixed() : _flexible = false;

  final bool _flexible;

  @override
  Map<String, Object?> _encode() => {
    'kind': _flexible ? 'flexibleSpace' : 'space',
  };
}

/// Puts a real `NSToolbar` with [items] on the window while this widget is
/// in the tree.
///
/// The toolbar belongs to the window, not to the widget tree: AppKit draws
/// it in the title bar above all Flutter content. A window has one toolbar,
/// so the most recently built [NativeToolbar] wins, and the toolbar goes
/// away when the widget is removed. On other platforms only [child] is
/// shown.
///
/// While mounted, the window also follows the app's theme brightness, so
/// the title bar matches a dark or light app.
class NativeToolbar extends StatefulWidget {
  const NativeToolbar({
    super.key,
    required this.items,
    required this.child,
    this.title,
    this.showsTitle = true,
    this.style = NativeToolbarStyle.unified,
  });

  final List<NativeToolbarItem> items;

  final Widget child;

  /// The window title. Null keeps the current one.
  final String? title;

  /// Whether the title is visible.
  final bool showsTitle;

  final NativeToolbarStyle style;

  @override
  State<NativeToolbar> createState() => _NativeToolbarState();
}

class _NativeToolbarState extends State<NativeToolbar> {
  static const _channel = MethodChannel('native_macos/toolbar');

  /// Mounted toolbars, newest last. The newest one owns the window, and the
  /// one below takes over when it goes away, as when a route is popped.
  static final _stack = <_NativeToolbarState>[];

  bool get _isActive => _stack.isNotEmpty && identical(_stack.last, this);

  Map<String, Object?>? _lastSent;
  int _windowRetries = 0;

  @override
  void initState() {
    super.initState();
    _stack.add(this);
    _channel.setMethodCallHandler(_onEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSend();
  }

  @override
  void didUpdateWidget(NativeToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSend();
  }

  @override
  void dispose() {
    final wasActive = _isActive;
    _stack.remove(this);
    if (wasActive) {
      if (_stack.isEmpty) {
        _channel.setMethodCallHandler(null);
        if (NativeMacos.isSupported) _channel.invokeMethod<void>('clear');
      } else {
        final next = _stack.last;
        _channel.setMethodCallHandler(next._onEvent);
        next._scheduleSend(force: true);
      }
    }
    super.dispose();
  }

  Map<String, Object?> _spec() {
    assert(() {
      final ids = [
        for (final item in widget.items)
          switch (item) {
            NativeToolbarButton(:final id) ||
            NativeToolbarSegments(:final id) ||
            NativeToolbarMenu(:final id) ||
            NativeToolbarSearch(:final id) => id,
            NativeToolbarSpace() => null,
          },
      ].nonNulls.toList();
      return ids.length == ids.toSet().length;
    }(), 'NativeToolbar item ids must be unique.');
    return {
      'title': widget.title,
      'showsTitle': widget.showsTitle,
      'style': widget.style.name,
      'brightness': nativeBrightness(context).name,
      'items': [for (final item in widget.items) item._encode()],
    };
  }

  /// Sends after the frame, when the Flutter view is in its window.
  void _scheduleSend({bool force = false}) {
    if (!NativeMacos.isSupported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _send(force: force));
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _send({bool force = false}) async {
    if (!mounted || !_isActive) return;
    final spec = _spec();
    if (!force && deepEquals(spec, _lastSent)) return;
    _lastSent = spec;
    try {
      await _channel.invokeMethod<void>('set', spec);
      _windowRetries = 0;
    } on PlatformException catch (e) {
      // The window can be missing for the first frames after launch.
      if (e.code != 'no_window' || ++_windowRetries > 60) rethrow;
      _lastSent = null;
      _scheduleSend();
    }
  }

  NativeToolbarItem? _item(Object? id) {
    for (final item in widget.items) {
      final itemId = switch (item) {
        NativeToolbarButton(:final id) ||
        NativeToolbarSegments(:final id) ||
        NativeToolbarMenu(:final id) ||
        NativeToolbarSearch(:final id) => id,
        NativeToolbarSpace() => null,
      };
      if (itemId == id) return item;
    }
    return null;
  }

  Future<Object?> _onEvent(MethodCall call) async {
    if (call.method != 'event' || !mounted) return null;
    final args = call.arguments as Map;
    final value = args['value'];
    switch (_item(args['id'])) {
      case NativeToolbarButton(:final onPressed):
        onPressed?.call();
      case NativeToolbarSegments(:final onChanged):
        onChanged?.call(value as int);
        // Puts Dart's selection back if the parent ignored the change.
        _scheduleSend(force: true);
      case final NativeToolbarMenu<Object?> menu:
        menu._select(value);
      case NativeToolbarSearch(:final onChanged, :final onSubmitted):
        if (args['type'] == 'submitted') {
          onSubmitted?.call(value as String);
        } else {
          onChanged?.call(value as String);
        }
      case NativeToolbarSpace() || null:
        break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
