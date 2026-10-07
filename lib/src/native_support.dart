import 'package:flutter/foundation.dart';

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

  /// Whether the OS draws Liquid Glass, which needs macOS 26 or later.
  ///
  /// An unknown version counts as no glass. The native side checks the
  /// version again, so this only helps decide what to show in Dart.
  static bool get hasLiquidGlass => (macOSVersion ?? 0) >= 26;

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
