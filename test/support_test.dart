import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_macos/native_macos.dart';

void main() {
  tearDown(() => NativeMacos.debugMacOSVersionOverride = null);

  test('parses the major macOS version', () {
    expect(NativeMacos.parseMacOSVersion('Version 27.0 (Build 26A428)'), 27);
    expect(NativeMacos.parseMacOSVersion('Version 15.6.1 (Build 24G90)'), 15);
    expect(NativeMacos.parseMacOSVersion('Linux 6.8'), isNull);
    expect(NativeMacos.parseMacOSVersion(null), isNull);
  });

  test('Liquid Glass needs macOS 26', () {
    NativeMacos.debugMacOSVersionOverride = 25;
    expect(NativeMacos.hasLiquidGlass, false);
    NativeMacos.debugMacOSVersionOverride = 26;
    expect(NativeMacos.hasLiquidGlass, true);
  });

  testWidgets('isSupported follows the target platform', (tester) async {
    expect(
      NativeMacos.isSupported,
      defaultTargetPlatform == TargetPlatform.macOS,
    );
  }, variant: TargetPlatformVariant.all());
}
