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

  String? title(MethodCall call) => (call.arguments as Map)['title'] as String?;

  testWidgets('the visible IndexedStack child owns the toolbar', (
    tester,
  ) async {
    Widget build(int index) => MaterialApp(
      home: IndexedStack(
        index: index,
        children: const [
          NativeToolbar(title: 'first', items: [], child: SizedBox()),
          NativeToolbar(title: 'second', items: [], child: SizedBox()),
        ],
      ),
    );
    await tester.pumpWidget(build(0));
    await tester.pump();
    // The second tab is mounted later but hidden, so it must not win.
    expect(title(calls.lastWhere((c) => c.method == 'set')), 'first');
    await tester.pumpWidget(build(1));
    await tester.pump();
    expect(title(calls.last), 'second');
    await tester.pumpWidget(build(0));
    await tester.pump();
    expect(title(calls.last), 'first');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a route without a toolbar removes the one below it', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const NativeToolbar(title: 'home', items: [], child: SizedBox()),
      ),
    );
    await tester.pump();
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('detail')),
    );
    await tester.pumpAndSettle();
    expect(calls.last.method, 'clear');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls.last.method, 'set');
    expect(title(calls.last), 'home');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('items are disabled and ignore events behind a dialog', (
    tester,
  ) async {
    var pressed = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: NativeToolbar(
          items: [
            NativeToolbarButton(
              id: 'b',
              label: 'B',
              onPressed: () => pressed++,
            ),
          ],
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(items(calls.last).single['enabled'], true);

    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const Text('dialog'),
    );
    await tester.pumpAndSettle();
    expect(items(calls.last).single['enabled'], false);
    await event(tester, {'id': 'b', 'type': 'pressed'});
    expect(pressed, 0);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(items(calls.last).single['enabled'], true);
    await event(tester, {'id': 'b', 'type': 'pressed'});
    expect(pressed, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a NativeInputBlocker above disables the items', (tester) async {
    Widget build(bool blocked) => MaterialApp(
      home: NativeInputBlocker(
        blocked: blocked,
        child: NativeToolbar(
          items: [NativeToolbarButton(id: 'b', label: 'B', onPressed: () {})],
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpWidget(build(false));
    await tester.pump();
    expect(items(calls.last).single['enabled'], true);
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(items(calls.last).single['enabled'], false);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a native failure is reported, not thrown asynchronously', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          throw PlatformException(code: 'boom', message: 'failed');
        });
    await tester.pumpWidget(
      const MaterialApp(
        home: NativeToolbar(items: [], child: SizedBox()),
      ),
    );
    await tester.pump();
    final error = tester.takeException();
    expect(error, isA<PlatformException>());
    expect((error as PlatformException).code, 'boom');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('updates carry the Dart session', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NativeToolbar(items: [], child: SizedBox()),
      ),
    );
    await tester.pump();
    expect((calls.last.arguments as Map)['session'], isA<String>());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('sends the display mode, tooltips, and direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: NativeToolbar(
            style: NativeToolbarStyle.expanded,
            displayMode: NativeToolbarDisplayMode.iconAndLabel,
            items: [
              NativeToolbarSegments(
                id: 'view',
                labels: const ['A', 'B'],
                tooltips: const ['First', 'Second'],
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ],
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
    final spec = calls.last.arguments as Map;
    expect(spec['displayMode'], 'iconAndLabel');
    expect(spec['rtl'], true);
    expect(items(calls.last).single['tooltips'], ['First', 'Second']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a search controller sets the field and follows typing', (
    tester,
  ) async {
    final controller = NativeToolbarSearchController(text: 'draft');
    addTearDown(controller.dispose);
    final changes = <String>[];
    var notified = 0;
    controller.addListener(() => notified++);
    await tester.pumpWidget(
      MaterialApp(
        home: NativeToolbar(
          items: [
            NativeToolbarSearch(
              id: 'search',
              controller: controller,
              onChanged: changes.add,
            ),
          ],
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    // The field starts empty, so the controller's text follows the set.
    expect(calls.map((c) => c.method), ['set', 'searchText']);
    expect(calls.last.arguments, {'id': 'search', 'text': 'draft'});

    controller.text = 'inbox';
    await tester.pump();
    expect(calls.last.arguments, {'id': 'search', 'text': 'inbox'});
    expect(changes, isEmpty);

    calls.clear();
    await event(tester, {'id': 'search', 'type': 'changed', 'value': 'in'});
    expect(controller.text, 'in');
    expect(changes, ['in']);
    // Typing is not echoed back to the field.
    expect(calls.where((c) => c.method == 'searchText'), isEmpty);

    controller.clear();
    await tester.pump();
    expect(calls.last.arguments, {'id': 'search', 'text': ''});
    expect(notified, 3);

    // Other updates leave an existing field's text alone.
    controller.text = 'kept';
    await tester.pump();
    calls.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: NativeToolbar(
          title: 'Changed',
          items: [NativeToolbarSearch(id: 'search', controller: controller)],
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(calls.map((c) => c.method), ['set']);
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
