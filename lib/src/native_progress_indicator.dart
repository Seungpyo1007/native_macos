import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;

import 'native_support.dart';
import 'native_types.dart';
import 'native_view.dart';

/// An AppKit `NSProgressIndicator`.
///
/// A null [value] is indeterminate. A [NativeProgressStyle.bar] takes the
/// parent's width.
class NativeProgressIndicator extends StatelessWidget {
  const NativeProgressIndicator({
    super.key,
    this.value,
    this.style = NativeProgressStyle.bar,
    this.controlSize = NativeControlSize.regular,
    this.fallback,
  }) : assert(value == null || (value >= 0 && value <= 1));

  /// Progress from 0 to 1, or null for indeterminate.
  final double? value;

  final NativeProgressStyle style;

  final NativeControlSize controlSize;

  /// Shown when native views are not supported. Defaults to a
  /// [LinearProgressIndicator] or a [CupertinoActivityIndicator].
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final bar = style == NativeProgressStyle.bar;
    if (!NativeMacos.isSupported) {
      if (fallback case final fallback?) return fallback;
      if (bar) return LinearProgressIndicator(value: value);
      return value == null
          ? const CupertinoActivityIndicator()
          : CupertinoActivityIndicator.partiallyRevealed(progress: value!);
    }
    final spinner = const [10.0, 16.0, 32.0, 32.0, 32.0][controlSize.index];
    return NativeView(
      viewType: 'progress',
      expand: bar,
      estimatedSize: bar ? const Size(160, 6) : Size(spinner, spinner),
      params: {
        'value': value,
        'style': style.name,
        'controlSize': controlSize.name,
      },
    );
  }
}
