import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'native_channel.dart';
import 'native_input_blocker.dart';
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

/// What toolbar items show (`NSToolbar.DisplayMode`).
///
/// AppKit shows labels only with [NativeToolbarStyle.expanded]; the unified
/// styles keep icons only whatever the mode.
enum NativeToolbarDisplayMode { iconOnly, iconAndLabel, labelOnly }

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
    this.tooltips,
  }) : assert(symbols == null || symbols.length == labels.length),
       assert(tooltips == null || tooltips.length == labels.length);

  final String id;

  /// One label per segment, shown when there is no symbol.
  final List<String> labels;

  /// One SF Symbol name per segment, shown instead of the labels.
  final List<String>? symbols;

  /// One help tag per segment.
  final List<String>? tooltips;

  final int selectedIndex;

  final ValueChanged<int>? onChanged;

  @override
  Map<String, Object?> _encode() => {
    'kind': 'segments',
    'id': id,
    'labels': labels,
    'symbols': symbols,
    'tooltips': tooltips,
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

/// The text of a [NativeToolbarSearch], readable and settable from Dart.
///
/// Typing in the field updates [text] and notifies listeners. Setting [text]
/// or calling [clear] changes the field without calling the search item's
/// `onChanged`.
class NativeToolbarSearchController extends ChangeNotifier {
  NativeToolbarSearchController({String? text}) : _text = text ?? '';

  String _text;

  String get text => _text;

  set text(String value) {
    if (value == _text) return;
    _text = value;
    _fromDart = true;
    notifyListeners();
    _fromDart = false;
  }

  /// Empties the field.
  void clear() => text = '';

  /// True while listeners hear about a change made from Dart, which the
  /// toolbar must send to the field.
  bool _fromDart = false;

  void _typed(String value) {
    if (value == _text) return;
    _text = value;
    notifyListeners();
  }
}

/// A search field that expands from a toolbar button
/// (`NSSearchToolbarItem`).
///
/// The field keeps its own text: [onChanged] reports each edit and
/// [onSubmitted] reports Return. A [controller] reads and sets the text
/// from Dart.
final class NativeToolbarSearch extends NativeToolbarItem {
  const NativeToolbarSearch({
    required this.id,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.controller,
  });

  final String id;

  final String? placeholder;

  final NativeToolbarSearchController? controller;

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
/// so among the [NativeToolbar]s that are visible, the most recently built
/// one wins. A toolbar in a hidden [IndexedStack] child or in a route
/// covered by an opaque route does not count, so the toolbar follows what
/// is on screen. When no visible [NativeToolbar] is left, the window's
/// toolbar goes away. On other platforms only [child] is shown.
///
/// While its route is covered by another one, such as a dialog, or while a
/// [NativeInputBlocker] above it blocks input, the toolbar's items are
/// disabled so they cannot act behind the overlay.
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
    this.displayMode = NativeToolbarDisplayMode.iconOnly,
  });

  final List<NativeToolbarItem> items;

  final Widget child;

  /// The window title. Null keeps the current one.
  final String? title;

  /// Whether the title is visible.
  final bool showsTitle;

  final NativeToolbarStyle style;

  /// Whether items show icons, labels, or both.
  final NativeToolbarDisplayMode displayMode;

  @override
  State<NativeToolbar> createState() => _NativeToolbarState();
}

class _NativeToolbarState extends State<NativeToolbar> {
  static const _channel = MethodChannel('native_macos/toolbar');

  /// Mounted toolbars, oldest first.
  static final _mounted = <_NativeToolbarState>[];

  /// The toolbar that owns the window: the newest visible one.
  static _NativeToolbarState? _owner;

  /// Whether this toolbar's subtree is on screen: tickers enabled (not in an
  /// offstage route) and not hidden by an [IndexedStack] or [Visibility].
  bool _visible = true;

  /// Whether this toolbar's items take input: its route is the current one
  /// and no [NativeInputBlocker] above it blocks.
  bool _interactive = true;

  Map<String, Object?>? _lastSent;
  int _windowRetries = 0;

  bool get _isActive => identical(_owner, this);

  /// The search controllers this toolbar listens to, by item id.
  final _controllers = <String, NativeToolbarSearchController>{};

  /// Search fields that already got their controller's text. A field keeps
  /// its text across updates, so only new ones are filled; filling one on
  /// every update could undo a keystroke still on its way to Dart.
  final _filledSearch = <String>{};

  @override
  void initState() {
    super.initState();
    _mounted.add(this);
    if (NativeMacos.isSupported) NativeMacos.loadCapabilities();
    _listenToControllers();
  }

  void _listenToControllers() {
    final next = <String, NativeToolbarSearchController>{
      for (final item in widget.items)
        if (item case NativeToolbarSearch(:final id, :final controller?))
          id: controller,
    };
    for (final MapEntry(key: id, value: old) in _controllers.entries) {
      if (!identical(next[id], old)) old.removeListener(_onControllerChanged);
    }
    for (final MapEntry(key: id, value: controller) in next.entries) {
      if (!identical(_controllers[id], controller)) {
        controller.addListener(_onControllerChanged);
      }
    }
    _controllers
      ..clear()
      ..addAll(next);
    // A removed field comes back empty.
    _filledSearch.retainAll(next.keys);
  }

  void _onControllerChanged() {
    if (!_isActive || !NativeMacos.isSupported) return;
    for (final MapEntry(key: id, value: controller) in _controllers.entries) {
      if (!controller._fromDart) continue;
      _channel
          .invokeMethod<bool>('searchText', {'id': id, 'text': controller.text})
          .catchError((Object error, StackTrace stack) {
            _report(error, stack);
            return false;
          });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled && Visibility.of(context);
    _interactive =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        !NativeInputBlocker.isBlocked(context);
    // A visibility change can move ownership to or from this toolbar.
    if (!_reassign()) _scheduleSend();
  }

  @override
  void didUpdateWidget(NativeToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listenToControllers();
    _scheduleSend();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_onControllerChanged);
    }
    _mounted.remove(this);
    _reassign();
    super.dispose();
  }

  /// Gives the window to the newest visible toolbar, or clears it when there
  /// is none. Returns whether the owner changed.
  static bool _reassign() {
    _NativeToolbarState? next;
    for (final state in _mounted.reversed) {
      if (state._visible) {
        next = state;
        break;
      }
    }
    if (identical(next, _owner)) return false;
    final hadOwner = _owner != null;
    _owner = next;
    if (next == null) {
      _channel.setMethodCallHandler(null);
      if (hadOwner && NativeMacos.isSupported) {
        _channel.invokeMethod<void>('clear').catchError(_report);
      }
    } else {
      _channel.setMethodCallHandler(next._onEvent);
      // The new owner's items are created again, empty.
      next._filledSearch.clear();
      next._scheduleSend(force: true);
    }
    return true;
  }

  static void _report(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'native_macos',
        context: ErrorDescription('while updating the native toolbar'),
      ),
    );
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
      'session': nativeSession,
      'title': widget.title,
      'showsTitle': widget.showsTitle,
      'style': widget.style.name,
      'displayMode': widget.displayMode.name,
      'brightness': nativeBrightness(context).name,
      // Menus and search fields follow it; item order follows the app's
      // language, as in every AppKit toolbar.
      'rtl': Directionality.maybeOf(context) == TextDirection.rtl,
      'items': [
        for (final item in widget.items)
          {
            ...item._encode(),
            // Items behind a dialog or blocker must not act; disabled is
            // also how AppKit shows a toolbar behind a sheet.
            if (!_interactive) 'enabled': false,
          },
      ],
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
      // A new field starts empty; its controller's text fills it.
      for (final MapEntry(key: id, value: controller) in _controllers.entries) {
        if (!_filledSearch.add(id) || controller.text.isEmpty) continue;
        await _channel.invokeMethod<bool>('searchText', {
          'id': id,
          'text': controller.text,
        });
      }
    } on PlatformException catch (e, stack) {
      // The window can be missing for the first frames after launch.
      if (e.code == 'no_window' && ++_windowRetries <= 60) {
        _lastSent = null;
        _scheduleSend();
      } else {
        _report(e, stack);
      }
    } on MissingPluginException catch (e, stack) {
      _report(e, stack);
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
    if (call.method != 'event' || !mounted || !_interactive) return null;
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
      case NativeToolbarSearch(
        :final onChanged,
        :final onSubmitted,
        :final controller,
      ):
        controller?._typed(value as String);
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
