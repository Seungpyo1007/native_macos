import 'package:flutter/services.dart';

import 'native_macos_exception.dart';

/// The plugin's channel for calls that are not tied to one view.
const nativeChannel = MethodChannel('native_macos');

/// Calls [method] on [nativeChannel] and turns platform errors into
/// [NativeMacosException].
Future<T?> invokeNative<T>(
  String method,
  Map<String, Object?> arguments,
) async {
  try {
    return await nativeChannel.invokeMethod<T>(method, arguments);
  } on PlatformException catch (e) {
    throw NativeMacosException(e.message ?? e.code, code: e.code);
  }
}
