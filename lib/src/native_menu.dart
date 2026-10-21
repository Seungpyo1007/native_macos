import 'package:flutter/widgets.dart';

import 'native_channel.dart';
import 'native_support.dart';
import 'native_view.dart';

/// An entry in a native menu: a [NativeMenuItem], a [NativeSubmenu], or a
/// [NativeMenuDivider].
sealed class NativeMenuEntry<T> {
  const NativeMenuEntry();
}

/// A key equivalent shown next to a menu item, such as ⌘C.
///
/// In a menu that a toolbar or [showNativeMenu] opens, pressing it while the
/// menu is open chooses the item. It does not register an app-wide shortcut.
final class NativeMenuShortcut {
  const NativeMenuShortcut(
    this.key, {
    this.command = true,
    this.shift = false,
    this.option = false,
    this.control = false,
  });

  /// One character, such as `c` or `,`.
  final String key;

  final bool command;
  final bool shift;
  final bool option;
  final bool control;

  Map<String, Object?> _encode() => {
    'key': key,
    'command': command,
    'shift': shift,
    'option': option,
    'control': control,
  };
}

/// A menu item that stands for [value].
final class NativeMenuItem<T> extends NativeMenuEntry<T> {
  const NativeMenuItem({
    required this.title,
    required this.value,
    this.symbol,
    this.enabled = true,
    this.checked = false,
    this.shortcut,
  });

  final String title;

  final T value;

  /// An SF Symbol name shown before [title].
  final String? symbol;

  final bool enabled;

  /// Shows a checkmark (`NSMenuItem.state`).
  final bool checked;

  final NativeMenuShortcut? shortcut;
}

/// An item that opens a nested menu of [items].
final class NativeSubmenu<T> extends NativeMenuEntry<T> {
  const NativeSubmenu({
    required this.title,
    required this.items,
    this.symbol,
    this.enabled = true,
  });

  final String title;

  final List<NativeMenuEntry<T>> items;

  final String? symbol;

  final bool enabled;
}

/// A separator line between menu items.
final class NativeMenuDivider<T> extends NativeMenuEntry<T> {
  const NativeMenuDivider();
}

/// Encodes [entries] for the native side.
///
/// Every entry gets a tag: its position when the entries and the entries of
/// their submenus are counted in order, so a flat list's tags are its
/// indices. The native side answers with the chosen item's tag.
List<Map<String, Object?>> encodeMenuEntries<T>(
  List<NativeMenuEntry<T>> entries,
) {
  var next = 0;
  List<Map<String, Object?>> encode(List<NativeMenuEntry<T>> list) => [
    for (final entry in list)
      switch (entry) {
        NativeMenuItem(
          :final title,
          :final symbol,
          :final enabled,
          :final checked,
          :final shortcut,
        ) =>
          {
            'tag': next++,
            'title': title,
            'symbol': symbol,
            'enabled': enabled,
            if (checked) 'checked': true,
            if (shortcut != null) 'shortcut': shortcut._encode(),
          },
        NativeSubmenu(
          :final title,
          :final symbol,
          :final enabled,
          :final items,
        ) =>
          {
            'tag': next++,
            'title': title,
            'symbol': symbol,
            'enabled': enabled,
            'submenu': encode(items),
          },
        NativeMenuDivider() => {'tag': next++, 'divider': true},
      },
  ];
  return encode(entries);
}

/// The value of the item with tag [index] from [encodeMenuEntries], or null
/// when there is no such item.
T? menuValueAt<T>(List<NativeMenuEntry<T>> entries, Object? index) {
  if (index is! int || index < 0) return null;
  var tag = 0;
  T? found;
  bool visit(List<NativeMenuEntry<T>> list) {
    for (final entry in list) {
      if (tag++ == index) {
        if (entry case NativeMenuItem(:final value)) found = value;
        return true;
      }
      if (entry case NativeSubmenu(:final items) when visit(items)) {
        return true;
      }
    }
    return false;
  }

  visit(entries);
  return found;
}

/// Pops up an `NSMenu` with [items] at [globalPosition], in the coordinates
/// of `PointerEvent.position`, and returns the chosen value.
///
/// Returns null when the menu is dismissed. Throws [UnsupportedError] off
/// macOS and [NativeMacosException] when the Flutter view has no window.
Future<T?> showNativeMenu<T>({
  required BuildContext context,
  required Offset globalPosition,
  required List<NativeMenuEntry<T>> items,
}) async {
  if (!NativeMacos.isSupported) {
    throw UnsupportedError('showNativeMenu only works on macOS.');
  }
  final index = await invokeNative<int>('showMenu', {
    'x': globalPosition.dx,
    'y': globalPosition.dy,
    'items': encodeMenuEntries(items),
    'brightness': nativeBrightness(context).name,
    'rtl': Directionality.maybeOf(context) == TextDirection.rtl,
  });
  return menuValueAt(items, index);
}
