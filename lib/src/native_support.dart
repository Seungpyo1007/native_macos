import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_channel.dart';
import 'native_platform.dart'
    if (dart.library.js_interop) 'native_platform_web.dart';

/// Runtime checks for the native macOS path.
abstract final class NativeMacos {
  /// Whether widgets embed AppKit views: true on macOS, false elsewhere,
  /// including the web.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// The major macOS version, such as 27, or null when it cannot be read.
  static int? get macOSVersion {
    if (debugMacOSVersionOverride != null) return debugMacOSVersionOverride;
    if (!isSupported) return null;
    return parseMacOSVersion(operatingSystemVersion());
  }

  /// Whether native views draw Liquid Glass.
  ///
  /// Glass needs macOS 26 and an app built with Xcode 26 or later. Once
  /// [loadCapabilities] has finished, which the first native widget starts,
  /// this is the native side's answer and covers both. Before that it only
  /// checks the macOS version, and an unknown version counts as no glass.
  static bool get hasLiquidGlass =>
      _nativeLiquidGlass ?? (macOSVersion ?? 0) >= 26;

  static bool? _nativeLiquidGlass;
  static Future<void>? _capabilities;

  /// Asks the native side what this build of the app can draw, so
  /// [hasLiquidGlass] also accounts for the Xcode version.
  ///
  /// Native widgets call this when they are first created; await it before
  /// reading [hasLiquidGlass] when the answer must be exact from the first
  /// frame. Completes without an answer on other platforms or when the
  /// plugin is missing.
  static Future<void> loadCapabilities() =>
      _capabilities ??= _loadCapabilities();

  static Future<void> _loadCapabilities() async {
    if (!isSupported) return;
    try {
      final caps = await nativeChannel.invokeMapMethod<String, Object?>(
        'capabilities',
        {'session': nativeSession},
      );
      final glass = caps?['liquidGlass'];
      if (glass is bool) _nativeLiquidGlass = glass;
    } on PlatformException {
      // Older native code; keep the version check.
    } on MissingPluginException {
      // No plugin, as in widget tests; keep the version check.
    }
  }

  /// Forgets the native answer from [loadCapabilities], in tests.
  @visibleForTesting
  static void debugResetCapabilities() {
    _nativeLiquidGlass = null;
    _capabilities = null;
  }

  /// Overrides [macOSVersion] in tests.
  @visibleForTesting
  static int? debugMacOSVersionOverride;

  /// Reads the major version from `Platform.operatingSystemVersion`, such as
  /// `Version 27.0 (Build 26A428)`.
  @visibleForTesting
  static int? parseMacOSVersion(String? text) {
    if (text == null) return null;
    final match = RegExp(r'Version (\d+)').firstMatch(text);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
