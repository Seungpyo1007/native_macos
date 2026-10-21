import 'dart:math';

import 'package:flutter/services.dart';

import 'native_macos_exception.dart';

/// The plugin's channel for calls that are not tied to one view.
const nativeChannel = MethodChannel('native_macos');

/// Identifies this Dart isolate to the native side.
///
/// A hot restart starts a new isolate while the native views and toolbar of
/// the previous one may still be alive. Channel names and toolbar updates
/// carry the session, so the two runs never answer for each other.
final String nativeSession = Random().nextInt(0x7fffffff).toRadixString(36);

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
