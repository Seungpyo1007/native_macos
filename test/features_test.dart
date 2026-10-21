import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_macos/native_macos.dart';
import 'package:native_macos/src/native_menu.dart';

import 'support/fake_platform_views.dart';

final _macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  late FakePlatformViews views;
  late List<MethodCall> calls;
  Object? reply;

  setUp(() {
    views = FakePlatformViews();
    calls = [];
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('native_macos'), (
          call,
        ) async {
          calls.add(call);
          return call.method == 'capabilities' ? null : reply;
        });
  });

  tearDown(() {
    NativeMacos.debugMacOSVersionOverride = null;
    NativeMacos.debugResetCapabilities();
  });

  group('accessibility', () {
    testWidgets('controls send their label, tooltip, and focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          NativeButton(
            label: '',
            symbol: 'trash',
            semanticsLabel: 'Delete',
            tooltip: 'Move to Trash',
            focusable: true,
            onPressed: () {},
          ),
        ),
      );
      final params = views.created['native_macos/button']!;
      expect(params['semanticsLabel'], 'Delete');
      expect(params['tooltip'], 'Move to Trash');
      expect(params['focusable'], true);
    }, variant: _macOS);

    testWidgets('controls refuse focus unless asked', (tester) async {
      await tester.pumpWidget(
        _app(NativeSwitch(value: true, onChanged: (_) {})),
      );
      final params = views.created['native_macos/switch']!;
      expect(params['focusable'], false);
      expect(params['semanticsLabel'], isNull);
    }, variant: _macOS);
  });

  group('buttons', () {
    testWidgets('default and cancel buttons send their keys', (tester) async {
      await tester.pumpWidget(
        _app(NativeButton(label: 'OK', isDefault: true, onPressed: () {})),
      );
      final params = views.created['native_macos/button']!;
      expect(params['isDefault'], true);
      expect(params['isCancel'], false);
    }, variant: _macOS);

    testWidgets('help button reports presses', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(NativeHelpButton(onPressed: () => pressed++)),
      );
      final params = views.created['native_macos/button']!;
      expect(params['kind'], 'help');
      expect(params['semanticsLabel'], 'Help');
      await views.emit(tester, 'native_macos/button', 'pressed');
      expect(pressed, 1);
    }, variant: _macOS);

    testWidgets('disclosure button reports the new state', (tester) async {
      bool? expanded;
      await tester.pumpWidget(
        _app(
          NativeDisclosureButton(
            expanded: false,
            onChanged: (v) => expanded = v,
          ),
        ),
      );
      final params = views.created['native_macos/button']!;
      expect(params['kind'], 'disclosure');
      expect(params['value'], false);
      await views.emit(tester, 'native_macos/button', 'changed', {
        'value': true,
      });
      expect(expanded, true);
    }, variant: _macOS);
  });

  group('segments', () {
    testWidgets('symbols and tooltips go with the selection', (tester) async {
      await tester.pumpWidget(
        _app(
          NativeSegmentedControl(
            labels: const ['Grid', 'List'],
            symbols: const ['square.grid.2x2', 'list.bullet'],
            segmentTooltips: const ['As icons', 'As list'],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        ),
      );
      final params = views.created['native_macos/segmented']!;
      expect(params['mode'], 'selectOne');
      expect(params['symbols'], ['square.grid.2x2', 'list.bullet']);
      expect(params['segmentTooltips'], ['As icons', 'As list']);
    }, variant: _macOS);

    testWidgets('segmented buttons report presses', (tester) async {
      final pressed = <int>[];
      await tester.pumpWidget(
        _app(
          NativeSegmentedButtons(
            labels: const ['Back', 'Forward'],
            onPressed: pressed.add,
          ),
        ),
      );
      expect(views.created['native_macos/segmented']!['mode'], 'momentary');
      await views.emit(tester, 'native_macos/segmented', 'pressed', {
        'value': 1,
      });
      await views.emit(tester, 'native_macos/segmented', 'pressed', {
        'value': -1,
      });
      expect(pressed, [1]);
    }, variant: _macOS);

    testWidgets('multi select sends and reports sets', (tester) async {
      Set<int>? changed;
      await tester.pumpWidget(
        _app(
          NativeMultiSegmentedControl(
            labels: const ['B', 'I', 'U'],
            selected: const {2, 0},
            onChanged: (v) => changed = v,
          ),
        ),
      );
      final params = views.created['native_macos/segmented']!;
      expect(params['mode'], 'selectAny');
      expect(params['selected'], [0, 2]);
      await views.emit(tester, 'native_macos/segmented', 'changed', {
        'value': [0, 1, 2],
      });
      expect(changed, {0, 1, 2});
    }, variant: _macOS);
  });

  group('new controls', () {
    testWidgets('date picker sends milliseconds and reports dates', (
      tester,
    ) async {
      final start = DateTime(2026, 10, 22, 9, 30);
      DateTime? picked;
      await tester.pumpWidget(
        _app(
          NativeDatePicker(
            value: start,
            elements: NativeDatePickerElements.dateAndTime,
            style: NativeDatePickerStyle.graphical,
            min: DateTime(2026),
            onChanged: (v) => picked = v,
          ),
        ),
      );
      final params = views.created['native_macos/datePicker']!;
      expect(params['value'], start.millisecondsSinceEpoch);
      expect(params['min'], DateTime(2026).millisecondsSinceEpoch);
      expect(params['max'], isNull);
      expect(params['style'], 'graphical');
      expect(params['elements'], 'dateAndTime');
      // Text field styles need focus to edit, so date pickers take it.
      expect(params['focusable'], true);
      final next = DateTime(2026, 12, 25);
      await views.emit(tester, 'native_macos/datePicker', 'changed', {
        'value': next.millisecondsSinceEpoch.toDouble(),
      });
      expect(picked, next);
    }, variant: _macOS);

    testWidgets('stepper sends its range and reports values', (tester) async {
      double? value;
      await tester.pumpWidget(
        _app(
          NativeStepper(
            value: 3,
            min: 1,
            max: 9,
            step: 2,
            wraps: true,
            onChanged: (v) => value = v,
          ),
        ),
      );
      final params = views.created['native_macos/stepper']!;
      expect(params['step'], 2);
      expect(params['wraps'], true);
      await views.emit(tester, 'native_macos/stepper', 'changed', {'value': 5});
      expect(value, 5);
    }, variant: _macOS);

    testWidgets('color well sends and reports ARGB colors', (tester) async {
      Color? color;
      await tester.pumpWidget(
        _app(
          NativeColorWell(
            value: const Color(0xFF336699),
            style: NativeColorWellStyle.minimal,
            onChanged: (v) => color = v,
          ),
        ),
      );
      final params = views.created['native_macos/colorWell']!;
      expect(params['value'], 0xFF336699);
      expect(params['style'], 'minimal');
      await views.emit(tester, 'native_macos/colorWell', 'changed', {
        'value': 0x80FF0000,
      });
      expect(color, const Color(0x80FF0000));
    }, variant: _macOS);
  });

  group('glass group', () {
    testWidgets('sends each item rect relative to the group', (tester) async {
      Widget build(double gap) => _app(
        SizedBox(
          width: 300,
          height: 100,
          child: NativeGlassGroup(
            spacing: 12,
            child: Row(
              children: [
                const NativeGlassGroupItem(
                  cornerRadius: 20,
                  child: SizedBox(width: 40, height: 40),
                ),
                SizedBox(width: gap),
                const NativeGlassGroupItem(
                  style: NativeGlassStyle.clear,
                  child: SizedBox(width: 60, height: 40),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(10));
      await tester.pumpAndSettle();
      List<Map<Object?, Object?>> shapes() {
        final updates = views.updates['native_macos/glassGroup'];
        final params = updates == null || updates.isEmpty
            ? views.created['native_macos/glassGroup']!
            : updates.last;
        return (params['shapes'] as List).cast();
      }

      expect(views.created['native_macos/glassGroup']!['spacing'], 12);
      var current = shapes();
      expect(current, hasLength(2));
      expect(current[0]['x'], 0);
      expect(current[0]['width'], 40);
      expect(current[0]['cornerRadius'], 20);
      expect(current[1]['x'], 50);
      expect(current[1]['style'], 'clear');
      final ids = [for (final s in current) s['id']];

      // Moving an item keeps its id, so the glass morphs.
      await tester.pumpWidget(build(30));
      await tester.pumpAndSettle();
      current = shapes();
      expect(current[1]['x'], 70);
      expect([for (final s in current) s['id']], ids);
    }, variant: _macOS);

    testWidgets('an item without a group is a glass container', (tester) async {
      await tester.pumpWidget(
        _app(
          const NativeGlassGroupItem(child: SizedBox(width: 10, height: 10)),
        ),
      );
      expect(find.byType(NativeGlassContainer), findsOneWidget);
    }, variant: _macOS);
  });

  group('sidebar', () {
    testWidgets('pads the content for glass and resizes', (tester) async {
      NativeMacos.debugMacOSVersionOverride = 26;
      final widths = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NativeSidebar(
            width: 200,
            resizable: true,
            onWidthChanged: widths.add,
            sidebar: const SizedBox.expand(key: Key('side')),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      expect(views.created['native_macos/sidebar']!['style'], 'automatic');
      expect(tester.getSize(find.byKey(const Key('side'))).width, 200 - 16);

      await tester.drag(
        find.byWidgetPredicate(
          (w) =>
              w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
        ),
        const Offset(40, 0),
      );
      await tester.pump();
      expect(widths.last, greaterThan(200));
      expect(widths.last, lessThanOrEqualTo(360));
    }, variant: _macOS);

    testWidgets('the material style does not pad', (tester) async {
      NativeMacos.debugMacOSVersionOverride = 26;
      await tester.pumpWidget(
        const MaterialApp(
          home: NativeSidebar(
            style: NativeSidebarStyle.material,
            sidebar: SizedBox.expand(key: Key('side')),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byKey(const Key('side'))).width, 220);
    }, variant: _macOS);
  });

  group('menus', () {
    const items = <NativeMenuEntry<String>>[
      NativeMenuItem(
        title: 'Copy',
        value: 'copy',
        checked: true,
        shortcut: NativeMenuShortcut('c', shift: true),
      ),
      NativeSubmenu(
        title: 'Sort',
        items: [
          NativeMenuItem(title: 'Name', value: 'name'),
          NativeMenuDivider(),
          NativeMenuItem(title: 'Size', value: 'size'),
        ],
      ),
      NativeMenuItem(title: 'Paste', value: 'paste'),
    ];

    test('tags count submenu entries in order', () {
      final encoded = encodeMenuEntries(items);
      expect(encoded[0]['tag'], 0);
      expect(encoded[0]['checked'], true);
      expect(encoded[0]['shortcut'], {
        'key': 'c',
        'command': true,
        'shift': true,
        'option': false,
        'control': false,
      });
      final submenu = (encoded[1]['submenu'] as List).cast<Map>();
      expect([for (final e in submenu) e['tag']], [2, 3, 4]);
      expect(encoded[2]['tag'], 5);
      expect(menuValueAt(items, 4), 'size');
      expect(menuValueAt(items, 5), 'paste');
      expect(menuValueAt(items, 1), isNull);
      expect(menuValueAt(items, 3), isNull);
      expect(menuValueAt(items, 9), isNull);
    });

    test('flat lists keep their indices as tags', () {
      const flat = <NativeMenuEntry<int>>[
        NativeMenuItem(title: 'A', value: 1),
        NativeMenuDivider(),
        NativeMenuItem(title: 'B', value: 2),
      ];
      expect([for (final e in encodeMenuEntries(flat)) e['tag']], [0, 1, 2]);
      expect(menuValueAt(flat, 2), 2);
    });
  });

  group('presenters', () {
    Future<BuildContext> pumpContext(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      return tester.element(find.byType(SizedBox));
    }

    testWidgets('popover sends the anchor and maps the action', (tester) async {
      final context = await pumpContext(tester);
      reply = 1;
      final value = await showNativePopover<String>(
        context: context,
        anchor: const Rect.fromLTWH(10, 20, 30, 40),
        title: 'Share',
        message: 'Send a link?',
        edge: NativePopoverEdge.trailing,
        actions: const [
          NativePopoverAction('Cancel', value: 'cancel'),
          NativePopoverAction('Send', value: 'send', isDefault: true),
        ],
      );
      expect(value, 'send');
      final args = calls.last.arguments as Map;
      expect(calls.last.method, 'showPopover');
      expect(
        [args['x'], args['y'], args['width'], args['height']],
        [10, 20, 30, 40],
      );
      expect(args['edge'], 'trailing');
      expect((args['actions'] as List)[1], {
        'title': 'Send',
        'isDefault': true,
        'destructive': false,
      });

      reply = null;
      expect(
        await showNativePopover<String>(
          context: context,
          anchor: Rect.zero,
          message: 'x',
        ),
        isNull,
      );
    }, variant: _macOS);

    testWidgets('popover needs content', (tester) async {
      final context = await pumpContext(tester);
      expect(
        () => showNativePopover<void>(context: context, anchor: Rect.zero),
        throwsArgumentError,
      );
    }, variant: _macOS);

    testWidgets('alert with result sends extras and reads the answer', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      reply = {'index': 0, 'suppressed': true, 'text': 'secret'};
      final result = await showNativeAlertWithResult(
        context: context,
        title: 'Password',
        buttons: const [NativeAlertButton('OK', isDefault: true)],
        suppressionLabel: 'Remember',
        textField: const NativeAlertTextField(
          placeholder: 'Password',
          secure: true,
        ),
      );
      expect(result.index, 0);
      expect(result.suppressed, true);
      expect(result.text, 'secret');
      final args = calls.last.arguments as Map;
      expect(args['detailed'], true);
      expect(args['suppressionLabel'], 'Remember');
      expect(args['textField'], {
        'text': '',
        'placeholder': 'Password',
        'secure': true,
      });
    }, variant: _macOS);

    testWidgets('window configure sends only what is set', (tester) async {
      reply = {'titlebarHeight': 52.0, 'fullSizeContent': true};
      final metrics = await NativeWindow.configure(
        subtitle: '3 items',
        fullSizeContent: true,
        separator: NativeTitlebarSeparator.none,
      );
      expect(metrics.titlebarHeight, 52);
      expect(metrics.fullSizeContent, true);
      expect(calls.last.method, 'configureWindow');
      expect(calls.last.arguments, {
        'subtitle': '3 items',
        'fullSizeContent': true,
        'transparentTitlebar': null,
        'separator': 'none',
      });
    }, variant: _macOS);
  });

  group('off macOS', () {
    testWidgets('new widgets show fallbacks', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              NativeDatePicker(value: DateTime(2026, 1, 2), onChanged: (_) {}),
              NativeStepper(value: 1, onChanged: (_) {}),
              NativeColorWell(
                value: const Color(0xFF000000),
                onChanged: (_) {},
              ),
              NativeHelpButton(onPressed: () {}),
              NativeDisclosureButton(expanded: true, onChanged: (_) {}),
              NativeSegmentedButtons(labels: const ['A'], onPressed: (_) {}),
              NativeMultiSegmentedControl(
                labels: const ['A'],
                selected: const {},
                onChanged: (_) {},
              ),
              const NativeGlassGroup(
                child: NativeGlassGroupItem(child: Text('glass')),
              ),
              const SizedBox(
                height: 50,
                child: NativeSidebar(
                  sidebar: Text('side'),
                  child: Text('main'),
                ),
              ),
            ],
          ),
        ),
      );
      expect(views.views, isEmpty);
      expect(find.text('2026-01-02'), findsOneWidget);
      expect(find.byType(CupertinoCheckbox), findsOneWidget);
      expect(find.text('glass'), findsOneWidget);
      expect(find.text('side'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('new presenters throw UnsupportedError', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      expect(
        () => showNativePopover<void>(
          context: context,
          anchor: Rect.zero,
          message: 'x',
        ),
        throwsUnsupportedError,
      );
      expect(NativeWindow.metrics, throwsUnsupportedError);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
