import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the engine's platform view channel and records the views
/// that widgets create.
class FakePlatformViews {
  FakePlatformViews() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, _onCall);
  }

  /// Creation params by view type, for views that are still alive.
  final created = <String, Map<Object?, Object?>>{};

  /// `update` calls sent to each view channel.
  final updates = <String, List<Map<Object?, Object?>>>{};

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
        created[type] = params;
        final channel = params['channel'] as String;
        _messenger.setMockMethodCallHandler(MethodChannel(channel), (c) async {
          if (c.method == 'update') {
            (updates[type] ??= []).add(c.arguments as Map);
          }
          return null;
        });
      case 'dispose':
        created.removeWhere((_, params) => params['id'] == call.arguments);
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
