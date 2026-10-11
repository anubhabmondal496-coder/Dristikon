import 'package:flutter_test/flutter_test.dart';
import 'package:blindfold/main.dart';
import 'package:blindfold/services/voice_service.dart';

void main() {
  testWidgets('BlindFold app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BlindFoldApp());

    // Verify that the title and key components render
    expect(find.text('BLINDFOLD'), findsOneWidget);

    if (VoiceService.instance.isBengali) {
      expect(find.text('অবস্ট্যাকল মোড'), findsOneWidget);
      expect(find.text('কারেন্সি রিডার'), findsOneWidget);
    } else {
      expect(find.text('Obstacle Avoidance'), findsOneWidget);
      expect(find.text('Currency Reader'), findsOneWidget);
    }
  });
}
