import 'package:floodsense2/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LandingPage loads and button navigates to HomePage', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const FloodSenseApp());

    // Check that "FloodSense" text is on screen
    expect(find.text('FloodSense'), findsOneWidget);

    // Tap the "Get Started" button
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // After navigation, check that HomePage content exists
    // Change this matcher to something unique from your HomePage
    expect(find.text('Welcome to FloodSense!'), findsOneWidget);
  });
}
