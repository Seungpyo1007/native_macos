import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_macos/native_macos.dart';

const _channel = MethodChannel('native_macos/toolbar');

void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  Future<void> event(WidgetTester tester, Map<String, Object?> args) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('event', args)),
      (_) {},
    );
    await tester.pump();
  }

  List<Map<Object?, Object?>> items(MethodCall call) =>
      ((call.arguments as Map)['items'] as List).cast();

  testWidgets('sends the items and reports their events', (tester) async {
    var pressed = 0;
    int? segment;
    String? sort;
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: NativeToolbar(
          title: 'Mail',
          style: NativeToolbarStyle.unifiedCompact,
          items: [
            NativeToolbarButton(
              id: 'new',
              label: 'New',
              symbol: 'square.and.pencil',
              prominent: true,
              badge: const NativeToolbarBadge.count(3),
              onPressed: () => pressed++,
            ),
            NativeToolbarSegments(
              id: 'view',
              labels: const ['A', 'B'],
              selectedIndex: 0,
              onChanged: (i) => segment = i,
            ),
            const NativeToolbarSpace.flexible(),
            NativeToolbarMenu<String>(
              id: 'sort',
              label: 'Sort',
              onSelected: (v) => sort = v,
              items: const [
                NativeMenuItem(title: 'Name', value: 'name'),
                NativeMenuDivider(),
                NativeMenuItem(title: 'Date', value: 'date'),
              ],
            ),
            NativeToolbarSearch(
              id: 'search',
              placeholder: 'Search',
              onSubmitted: (t) => submitted = t,
            ),
          ],
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    final set = calls.single;
    expect(set.method, 'set');
    final spec = set.arguments as Map;
    expect(spec['title'], 'Mail');
    expect(spec['style'], 'unifiedCompact');
    expect(items(set).map((i) => i['kind']), [
      'button',
      'segments',
      'flexibleSpace',
      'menu',
      'search',
    ]);
    expect(items(set).first['badge'], {
      'count': 3,
      'text': null,
      'indicator': false,
    });

    await event(tester, {'id': 'new', 'type': 'pressed'});
    await event(tester, {'id': 'view', 'type': 'changed', 'value': 1});
    await event(tester, {'id': 'sort', 'type': 'selected', 'value': 2});
    await event(tester, {
      'id': 'search',
      'type': 'submitted',
      'value': 'hello',
    });
    expect(pressed, 1);
    expect(segment, 1);
    expect(sort, 'date');
    expect(submitted, 'hello');
    // The ignored segment change is put back.
    expect(items(calls.last)[1]['selectedIndex'], 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('does not resend an unchanged toolbar', (tester) async {
    Widget build() => MaterialApp(
      home: NativeToolbar(
        items: [
          NativeToolbarMenu<int>(
            id: 'm',
            label: 'M',
            onSelected: (_) {},
            items: [
              for (var i = 0; i < 2; i++) NativeMenuItem(title: '$i', value: i),
            ],
          ),
        ],
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pumpWidget(build());
    await tester.pump();
    expect(calls.where((c) => c.method == 'set'), hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the toolbar below comes back when the top one goes away', (
    tester,
  ) async {
    Widget build(bool second) => MaterialApp(
      home: NativeToolbar(
        title: 'first',
        items: const [],
        child: second
            ? const NativeToolbar(title: 'second', items: [], child: SizedBox())
            : const SizedBox(),
      ),
    );
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect((calls.last.arguments as Map)['title'], 'second');
    await tester.pumpWidget(build(false));
    await tester.pump();
    expect((calls.last.arguments as Map)['title'], 'first');

    await tester.pumpWidget(const SizedBox());
    expect(calls.last.method, 'clear');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('retries until the window exists', (tester) async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'set' && ++attempts < 3) {
            throw PlatformException(code: 'no_window');
          }
          return null;
        });
    await tester.pumpWidget(
      const MaterialApp(
        home: NativeToolbar(items: [], child: SizedBox()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(attempts, 3);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('shows only the child elsewhere', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NativeToolbar(items: [], child: Text('page')),
      ),
    );
    await tester.pump();
    expect(find.text('page'), findsOneWidget);
    expect(calls, isEmpty);
  }, variant: TargetPlatformVariant.all(excluding: {TargetPlatform.macOS}));
}
