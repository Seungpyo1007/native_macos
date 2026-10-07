import 'package:flutter/cupertino.dart';

import 'native_menu.dart';
import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// An AppKit `NSPopUpButton` that shows the item whose value is [value].
///
/// A null [onChanged] disables the button.
class NativePopUpButton<T> extends StatefulWidget {
  const NativePopUpButton({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.controlSize = NativeControlSize.regular,
    this.fallback,
  });

  final List<NativeMenuEntry<T>> items;

  /// The selected value. Null, or a value no item has, selects nothing.
  final T? value;

  final ValueChanged<T>? onChanged;

  final NativeControlSize controlSize;

  /// Shown when native views are not supported. Defaults to a
  /// [CupertinoButton] that opens a [CupertinoActionSheet].
  final Widget? fallback;

  @override
  State<NativePopUpButton<T>> createState() => _NativePopUpButtonState<T>();
}

class _NativePopUpButtonState<T> extends State<NativePopUpButton<T>> {
  final _view = GlobalKey<NativeViewState>();

  int get _selectedIndex => widget.items.indexWhere(
    (entry) => entry is NativeMenuItem<T> && entry.value == widget.value,
  );

  String get _selectedTitle => switch (_selectedIndex) {
    -1 => '',
    final i => (widget.items[i] as NativeMenuItem<T>).title,
  };

  @override
  Widget build(BuildContext context) {
    if (!NativeMacos.isSupported) {
      return widget.fallback ?? _fallback(context);
    }
    final longest = widget.items.whereType<NativeMenuItem<T>>().fold<double>(
      0,
      (max, item) {
        final width = estimatedTextWidth(item.title, padding: 40);
        return width > max ? width : max;
      },
    );
    return NativeView(
      key: _view,
      viewType: 'popup',
      enabled: widget.onChanged != null,
      estimatedSize: Size(
        longest,
        estimatedControlHeight(widget.controlSize.index),
      ),
      params: {
        'items': encodeMenuEntries(widget.items),
        'selectedIndex': _selectedIndex,
        'controlSize': widget.controlSize.name,
      },
      onEvent: (method, arguments) {
        if (method != 'changed') return;
        final value = menuValueAt(widget.items, (arguments as Map)['value']);
        if (value is T) widget.onChanged?.call(value);
        _view.currentState?.resync();
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final onChanged = widget.onChanged;
    return CupertinoButton(
      onPressed: onChanged == null
          ? null
          : () => showCupertinoModalPopup<void>(
              context: context,
              builder: (context) => CupertinoActionSheet(
                actions: [
                  for (final item
                      in widget.items.whereType<NativeMenuItem<T>>())
                    CupertinoActionSheetAction(
                      onPressed: item.enabled
                          ? () {
                              Navigator.pop(context);
                              onChanged(item.value);
                            }
                          : () {},
                      child: Text(item.title),
                    ),
                ],
              ),
            ),
      child: Text(_selectedTitle),
    );
  }
}
