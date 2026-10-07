import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_macos/native_macos.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native views report a size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              NativeButton(label: 'OK', onPressed: () {}),
              NativeSwitch(value: true, onChanged: (_) {}),
              NativeSegmentedControl(
                labels: const ['A', 'B'],
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    // The native side reports its fitting size after the view is created.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final type in [NativeButton, NativeSwitch, NativeSegmentedControl]) {
      final size = tester.getSize(find.byType(type));
      expect(size.width, greaterThan(0), reason: '$type');
      expect(size.height, greaterThan(0), reason: '$type');
    }
    expect(NativeMacos.macOSVersion, isNotNull);
  });
}
