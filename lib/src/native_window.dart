import 'native_channel.dart';
import 'native_support.dart';

/// The line between the title bar and the content
/// (`NSTitlebarSeparatorStyle`).
enum NativeTitlebarSeparator { automatic, none, line, shadow }

/// Sizes of the window that Flutter cannot see.
final class NativeWindowMetrics {
  const NativeWindowMetrics({
    required this.titlebarHeight,
    required this.fullSizeContent,
  });

  /// The height of the title bar, toolbar included. With [fullSizeContent],
  /// Flutter draws under it, so pad content that must stay visible by this
  /// much.
  final double titlebarHeight;

  /// Whether the content extends under the title bar.
  final bool fullSizeContent;
}

/// The window that shows the Flutter view.
abstract final class NativeWindow {
  /// Changes the window's title bar. Null arguments keep the current value.
  ///
  /// [subtitle] shows under the title (`NSWindow.subtitle`).
  /// [fullSizeContent] lets Flutter draw under the title bar
  /// (`fullSizeContentView`), and [transparentTitlebar] removes the title
  /// bar's own background, so the app's content shows through it.
  ///
  /// Returns the window's metrics afterwards. Throws [UnsupportedError] off
  /// macOS and `NativeMacosException` when the Flutter view has no window.
  static Future<NativeWindowMetrics> configure({
    String? subtitle,
    bool? fullSizeContent,
    bool? transparentTitlebar,
    NativeTitlebarSeparator? separator,
  }) async {
    _checkSupported();
    final reply = await invokeNative<Map<Object?, Object?>>('configureWindow', {
      'subtitle': subtitle,
      'fullSizeContent': fullSizeContent,
      'transparentTitlebar': transparentTitlebar,
      'separator': separator?.name,
    });
    return _metrics(reply);
  }

  /// The window's current metrics.
  static Future<NativeWindowMetrics> metrics() async {
    _checkSupported();
    return _metrics(
      await invokeNative<Map<Object?, Object?>>('windowMetrics', const {}),
    );
  }

  static NativeWindowMetrics _metrics(Map<Object?, Object?>? reply) =>
      NativeWindowMetrics(
        titlebarHeight: (reply?['titlebarHeight'] as num? ?? 0).toDouble(),
        fullSizeContent: reply?['fullSizeContent'] as bool? ?? false,
      );

  static void _checkSupported() {
    if (!NativeMacos.isSupported) {
      throw UnsupportedError('NativeWindow only works on macOS.');
    }
  }
}
