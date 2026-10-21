import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the engine's platform view channel and records the views
/// that widgets create.
class FakePlatformViews {
  FakePlatformViews() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, _onCall);
  }

  /// Live views by platform view id, in creation order.
  final views = <int, ({String type, Map<Object?, Object?> params})>{};

  /// `update` calls sent to each view channel, by view type.
  final updates = <String, List<Map<Object?, Object?>>>{};

  /// Creation params of the newest live view of each type.
  Map<String, Map<Object?, Object?>> get created => {
    for (final view in views.values) view.type: view.params,
  };

  /// Creation params of every live view of [type], oldest first.
  List<Map<Object?, Object?>> all(String type) => [
    for (final view in views.values)
      if (view.type == type) view.params,
  ];

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'create':
        final args = call.arguments as Map;
        final bytes = args['params'] as Uint8List;
        final params = const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        ) as Map;
        final type = args['viewType'] as String;
        views[args['id'] as int] = (type: type, params: params);
        final channel = params['channel'] as String;
        _messenger.setMockMethodCallHandler(MethodChannel(channel), (c) async {
          if (c.method == 'update') {
            (updates[type] ??= []).add(c.arguments as Map);
          }
          return null;
        });
      case 'dispose':
        // The engine disposes by platform view id.
        final id = call.arguments is Map
            ? (call.arguments as Map)['id']
            : call.arguments;
        final view = views.remove(id);
        if (view != null) {
          _messenger.setMockMethodCallHandler(
            MethodChannel(view.params['channel'] as String),
            null,
          );
        }
    }
    return null;
  }

  /// Sends [method] from the native view of [viewType] to Dart.
  Future<void> emit(
    WidgetTester tester,
    String viewType,
    String method, [
    Object? arguments,
  ]) async {
    final channel = created[viewType]!['channel'] as String;
    await _messenger.handlePlatformMessage(
      channel,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
    await tester.pump();
  }
}
