// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ridewithgarv/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows onboarding after session restore', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RidersCommunityApp());
    // Session restore + onboarding may include non-idle animations; avoid pumpAndSettle.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Riders Communities').evaluate().isNotEmpty) break;
    }
    expect(find.text('Riders Communities'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
