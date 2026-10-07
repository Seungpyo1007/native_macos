import 'package:flutter/widgets.dart';

import 'native_channel.dart';
import 'native_support.dart';
import 'native_view.dart';

/// An entry in a native menu: a [NativeMenuItem] or a [NativeMenuDivider].
sealed class NativeMenuEntry<T> {
  const NativeMenuEntry();
}

/// A menu item that stands for [value].
final class NativeMenuItem<T> extends NativeMenuEntry<T> {
  const NativeMenuItem({
    required this.title,
    required this.value,
    this.symbol,
    this.enabled = true,
  });

  final String title;

  final T value;

  /// An SF Symbol name shown before [title].
  final String? symbol;

  final bool enabled;
}

/// A separator line between menu items.
final class NativeMenuDivider<T> extends NativeMenuEntry<T> {
  const NativeMenuDivider();
}

/// Encodes [entries] for the native side.
List<Map<String, Object?>> encodeMenuEntries<T>(
  List<NativeMenuEntry<T>> entries,
) => [
  for (final entry in entries)
    switch (entry) {
      NativeMenuItem(:final title, :final symbol, :final enabled) => {
        'title': title,
        'symbol': symbol,
        'enabled': enabled,
      },
      NativeMenuDivider() => {'divider': true},
    },
];

/// The value of the item at [index] in [entries], or null when the index is
/// out of range or not an item.
T? menuValueAt<T>(List<NativeMenuEntry<T>> entries, Object? index) {
  if (index is! int || index < 0 || index >= entries.length) return null;
  return switch (entries[index]) {
    NativeMenuItem(:final value) => value,
    NativeMenuDivider() => null,
  };
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
