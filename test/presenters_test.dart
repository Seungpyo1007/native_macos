import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_macos/native_macos.dart';

void main() {
  late List<MethodCall> calls;
  Object? reply;

  setUp(() {
    calls = [];
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('native_macos'), (
          call,
        ) async {
          calls.add(call);
          if (reply is PlatformException) throw reply!;
          return reply;
        });
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    return tester.element(find.byType(SizedBox));
  }

  testWidgets('showNativeAlert sends the buttons and returns the index', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    reply = 1;
    final index = await showNativeAlert(
      context: context,
      title: 'Delete?',
      message: 'Gone for good.',
      style: NativeAlertStyle.critical,
      buttons: const [
        NativeAlertButton('Delete', destructive: true),
        NativeAlertButton('Cancel', isDefault: true),
      ],
    );
    expect(index, 1);
    final args = calls.single.arguments as Map;
    expect(calls.single.method, 'showAlert');
    expect(args['style'], 'critical');
    expect(args['asSheet'], true);
    expect(args['buttons'], [
      {
        'title': 'Delete',
        'destructive': true,
        'isDefault': false,
        'isCancel': false,
      },
      {
        'title': 'Cancel',
        'destructive': false,
        'isDefault': true,
        'isCancel': false,
      },
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('showNativeAlert rejects an empty button list', (tester) async {
    final context = await pumpContext(tester);
    expect(
      () => showNativeAlert(context: context, title: 'x', buttons: const []),
      throwsArgumentError,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('showNativeMenu maps the index and handles dismissal', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    const items = [
      NativeMenuItem(title: 'Copy', value: 'copy'),
      NativeMenuDivider<String>(),
      NativeMenuItem(title: 'Paste', value: 'paste'),
    ];
    reply = 2;
    expect(
      await showNativeMenu(
        context: context,
        globalPosition: const Offset(10, 20),
        items: items,
      ),
      'paste',
    );
    final args = calls.single.arguments as Map;
    expect(args['x'], 10);
    expect(args['y'], 20);

    reply = null;
    expect(
      await showNativeMenu(
        context: context,
        globalPosition: Offset.zero,
        items: items,
      ),
      isNull,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('native errors become NativeMacosException', (tester) async {
    final context = await pumpContext(tester);
    reply = PlatformException(code: 'no_window', message: 'No window.');
    await expectLater(
      showNativeAlert(
        context: context,
        title: 'x',
        buttons: const [NativeAlertButton('OK')],
      ),
      throwsA(
        isA<NativeMacosException>()
            .having((e) => e.code, 'code', 'no_window')
            .having((e) => e.toString(), 'toString', 'No window.'),
      ),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
