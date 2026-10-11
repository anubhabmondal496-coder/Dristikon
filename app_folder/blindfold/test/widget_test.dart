import 'package:flutter_test/flutter_test.dart';
import 'package:blindfold/main.dart';

void main() {
  testWidgets('BlindFold app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BlindFoldApp());

    // Verify that the title and key components render
    expect(find.text('BLINDFOLD'), findsOneWidget);
    expect(find.text('Obstacle Avoidance'), findsOneWidget);
    expect(find.text('Currency Reader'), findsOneWidget);
  });
}
