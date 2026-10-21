import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:native_macos/native_macos.dart';
import 'package:native_macos/src/native_channel.dart';

import 'support/fake_platform_views.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('on macOS', () {
    late FakePlatformViews views;

    setUp(() => views = FakePlatformViews());

    testWidgets('NativeButton sends its settings and calls onPressed', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(
          NativeButton(
            label: 'Save',
            style: NativeButtonStyle.glass,
            prominence: NativeTintProminence.primary,
            tint: const Color(0xFF112233),
            onPressed: () => pressed++,
          ),
        ),
      );
      await tester.pump();

      final params = views.created['native_macos/button']!;
      expect(params['label'], 'Save');
      expect(params['style'], 'glass');
      expect(params['prominence'], 'primary');
      expect(params['tint'], 0xFF112233);
      expect(params['enabled'], true);
      expect(params['brightness'], 'light');
      expect(params['rtl'], false);
      expect(params['interactive'], true);

      await views.emit(tester, 'native_macos/button', 'pressed');
      expect(pressed, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('takes the size the native view reports', (tester) async {
      await tester.pumpWidget(
        _app(NativeButton(label: 'OK', onPressed: () {})),
      );
      await tester.pump();
      await views.emit(tester, 'native_macos/button', 'size', {
        'width': 77.0,
        'height': 31.0,
      });
      expect(tester.getSize(find.byType(NativeButton)), const Size(77, 31));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('sends an update only when something changed', (tester) async {
      Widget build(String label, Brightness brightness) => _app(
        NativeButton(label: label, onPressed: () {}),
        brightness: brightness,
      );
      await tester.pumpWidget(build('A', Brightness.light));
      await tester.pump();
      await tester.pumpWidget(build('A', Brightness.light));
      expect(views.updates['native_macos/button'], isNull);

      await tester.pumpWidget(build('A', Brightness.dark));
      await tester.pumpAndSettle();
      expect(views.updates['native_macos/button']!.last['brightness'], 'dark');

      await tester.pumpWidget(build('B', Brightness.dark));
      await tester.pumpAndSettle();
      expect(views.updates['native_macos/button']!.last['label'], 'B');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'NativeSwitch puts the value back when the parent ignores a change',
      (tester) async {
        bool? reported;
        await tester.pumpWidget(
          _app(NativeSwitch(value: false, onChanged: (v) => reported = v)),
        );
        await tester.pump();
        await views.emit(tester, 'native_macos/switch', 'changed', {
          'value': true,
        });
        await tester.pump();
        expect(reported, true);
        expect(views.updates['native_macos/switch']!.last['value'], false);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('NativeCheckbox puts the value back when ignored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(NativeCheckbox(value: true, label: 'A', onChanged: (_) {})),
      );
      await tester.pump();
      await views.emit(tester, 'native_macos/checkbox', 'changed', {
        'value': false,
      });
      await tester.pump();
      expect(views.updates['native_macos/checkbox']!.last['value'], true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('NativePopUpButton puts the selection back when ignored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          NativePopUpButton<String>(
            value: 'b',
            onChanged: (_) {},
            items: const [
              NativeMenuItem(title: 'A', value: 'a'),
              NativeMenuItem(title: 'B', value: 'b'),
            ],
          ),
        ),
      );
      await tester.pump();
      await views.emit(tester, 'native_macos/popup', 'changed', {'value': 0});
      await tester.pump();
      expect(views.updates['native_macos/popup']!.last['selectedIndex'], 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('NativeSlider resyncs only when the drag ends', (tester) async {
      await tester.pumpWidget(
        _app(NativeSlider(value: 0.2, onChanged: (_) {})),
      );
      await tester.pump();
      await views.emit(tester, 'native_macos/slider', 'changed', {
        'value': 0.5,
      });
      await tester.pump();
      // Mid-drag, sending the old value would fight the knob.
      expect(views.updates['native_macos/slider'], isNull);
      await views.emit(tester, 'native_macos/slider', 'changeEnded', {
        'value': 0.5,
      });
      await tester.pump();
      expect(views.updates['native_macos/slider']!.last['value'], 0.2);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('view channels are unique and carry the Dart session', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              NativeButton(label: 'A', onPressed: () {}),
              NativeButton(label: 'B', onPressed: () {}),
            ],
          ),
        ),
      );
      await tester.pump();
      final channels = [
        for (final params in views.all('native_macos/button'))
          params['channel'] as String,
      ];
      expect(channels, hasLength(2));
      expect(channels.toSet(), hasLength(2));
      // A hot restart starts a new session, so its names never collide with
      // the previous run's views.
      for (final name in channels) {
        expect(name, startsWith('native_macos/view_${nativeSession}_'));
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a removed view is disposed', (tester) async {
      await tester.pumpWidget(_app(NativeButton(label: 'A', onPressed: () {})));
      await tester.pump();
      expect(views.all('native_macos/button'), hasLength(1));
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pump();
      expect(views.all('native_macos/button'), isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a failed update is reported, not thrown asynchronously', (
      tester,
    ) async {
      Widget build(String label) =>
          _app(NativeButton(label: label, onPressed: () {}));
      await tester.pumpWidget(build('A'));
      await tester.pump();
      final channel = views.created['native_macos/button']!['channel'];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel as String), (
            call,
          ) async {
            throw PlatformException(code: 'broken');
          });
      await tester.pumpWidget(build('B'));
      await tester.pump();
      expect(tester.takeException(), isA<PlatformException>());
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('NativeSegmentedControl reports the index', (tester) async {
      int? selected;
      await tester.pumpWidget(
        _app(
          NativeSegmentedControl(
            labels: const ['A', 'B', 'C'],
            selectedIndex: 0,
            onChanged: (i) => selected = i,
          ),
        ),
      );
      await tester.pump();
      expect(views.created['native_macos/segmented']!['labels'], [
        'A',
        'B',
        'C',
      ]);
      await views.emit(tester, 'native_macos/segmented', 'changed', {
        'value': 2,
      });
      expect(selected, 2);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('NativeSlider reports changes and the end of a drag', (
      tester,
    ) async {
      final changes = <double>[];
      double? ended;
      await tester.pumpWidget(
        _app(
          NativeSlider(
            value: 0.2,
            onChanged: changes.add,
            onChangeEnd: (v) => ended = v,
          ),
        ),
      );
      await tester.pump();
      await views.emit(tester, 'native_macos/slider', 'changed', {
        'value': 0.5,
      });
      await views.emit(tester, 'native_macos/slider', 'changeEnded', {
        'value': 0.6,
      });
      expect(changes, [0.5]);
      expect(ended, 0.6);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('NativePopUpButton maps the native index to a value', (
      tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(
        _app(
          NativePopUpButton<String>(
            value: 'b',
            onChanged: (v) => chosen = v,
            items: const [
              NativeMenuItem(title: 'A', value: 'a'),
              NativeMenuDivider(),
              NativeMenuItem(title: 'B', value: 'b'),
            ],
          ),
        ),
      );
      await tester.pump();
      final params = views.created['native_macos/popup']!;
      expect(params['selectedIndex'], 2);
      expect((params['items'] as List)[1], {'tag': 1, 'divider': true});
      await views.emit(tester, 'native_macos/popup', 'changed', {'value': 0});
      expect(chosen, 'a');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a null callback disables the control', (tester) async {
      await tester.pumpWidget(
        _app(const NativeCheckbox(value: true, onChanged: null)),
      );
      await tester.pump();
      expect(views.created['native_macos/checkbox']!['enabled'], false);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('NativeInputBlocker turns off native input below it', (
      tester,
    ) async {
      Widget build(bool blocked) => _app(
        NativeInputBlocker(
          blocked: blocked,
          child: NativeInputBlocker(
            blocked: false,
            child: NativeButton(label: 'OK', onPressed: () {}),
          ),
        ),
      );
      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(views.created['native_macos/button']!['interactive'], true);
      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(views.updates['native_macos/button']!.last['interactive'], false);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('NativeGlassContainer paints its child over the glass', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const NativeGlassContainer(
            cornerRadius: 24,
            style: NativeGlassStyle.clear,
            child: SizedBox(width: 120, height: 40, child: Text('Hi')),
          ),
        ),
      );
      await tester.pump();
      final params = views.created['native_macos/glass']!;
      expect(params['cornerRadius'], 24);
      expect(params['style'], 'clear');
      expect(find.text('Hi'), findsOneWidget);
      expect(
        tester.getSize(find.byType(NativeGlassContainer)),
        const Size(120, 40),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    testWidgets(
      'a change made while the view is being created still goes out',
      (tester) async {
        Widget build(bool value) =>
            _app(NativeSwitch(value: value, onChanged: (_) {}));
        await tester.pumpWidget(build(false));
        // Rebuild before the platform view has finished creating.
        await tester.pumpWidget(build(true));
        await tester.pumpAndSettle();
        expect(views.created['native_macos/switch']!['value'], false);
        expect(views.updates['native_macos/switch']!.last['value'], true);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('rebuilding with equal but new lists sends nothing', (
      tester,
    ) async {
      Widget build() => _app(
        NativePopUpButton<int>(
          value: 1,
          onChanged: (_) {},
          items: [
            for (var i = 0; i < 3; i++)
              NativeMenuItem(title: 'Item $i', value: i),
          ],
        ),
      );
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pumpWidget(build());
      await tester.pumpWidget(build());
      expect(views.updates['native_macos/popup'], isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a slider keeps the parent width and takes the native height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 300,
            child: NativeSlider(value: 0.5, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pump();
      await views.emit(tester, 'native_macos/slider', 'size', {
        'width': 0.0,
        'height': 19.0,
      });
      expect(tester.getSize(find.byType(NativeSlider)), const Size(300, 19));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('an out-of-range segment index fails an assert', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          NativeSegmentedControl(
            labels: const ['A', 'B'],
            selectedIndex: 2,
            onChanged: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('elsewhere', () {
    final others = TargetPlatformVariant.all(excluding: {TargetPlatform.macOS});

    testWidgets('controls show Flutter fallbacks', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              NativeButton(label: 'Go', onPressed: () {}),
              NativeSwitch(value: true, onChanged: (_) {}),
              NativeSlider(value: 0.5, onChanged: (_) {}),
              const NativeProgressIndicator(value: 0.3),
            ],
          ),
        ),
      );
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.byType(CupertinoSlider), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(AppKitView), findsNothing);
    }, variant: others);

    testWidgets('a custom fallback replaces the default', (tester) async {
      await tester.pumpWidget(
        _app(
          NativeButton(
            label: 'Go',
            onPressed: () {},
            fallback: const Text('custom'),
          ),
        ),
      );
      expect(find.text('custom'), findsOneWidget);
    }, variant: others);

    testWidgets('glass shows the child as is', (tester) async {
      await tester.pumpWidget(
        _app(const NativeGlassContainer(child: Text('plain'))),
      );
      expect(find.text('plain'), findsOneWidget);
      expect(find.byType(AppKitView), findsNothing);
    }, variant: others);

    testWidgets('presenters throw UnsupportedError', (tester) async {
      await tester.pumpWidget(_app(const SizedBox()));
      final context = tester.element(find.byType(Center));
      expect(
        () => showNativeAlert(
          context: context,
          title: 'x',
          buttons: const [NativeAlertButton('OK')],
        ),
        throwsUnsupportedError,
      );
      expect(
        () => showNativeMenu<int>(
          context: context,
          globalPosition: Offset.zero,
          items: const [],
        ),
        throwsUnsupportedError,
      );
    }, variant: others);
  });
}
