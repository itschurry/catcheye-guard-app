import 'package:flutter_test/flutter_test.dart';
import 'package:catcheye_guard_app/main.dart';

void main() {
  testWidgets('App starts and shows navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const CatchEyeGuardApp());
    await tester.pumpAndSettle();

    // Verify NavigationRail is present
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('ROI Editor'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
  });
}
