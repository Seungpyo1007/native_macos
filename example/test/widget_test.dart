import 'package:flutter_test/flutter_test.dart';
import 'package:native_macos_example/main.dart';

void main() {
  testWidgets('shows every section with the fallback widgets', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Buttons'), findsOneWidget);
    expect(find.text('Toggles'), findsOneWidget);
  });
}
