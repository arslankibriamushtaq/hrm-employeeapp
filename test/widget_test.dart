import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hr_employee_app/main.dart';
import 'package:hr_employee_app/session.dart';

void main() {
  testWidgets('Signed-out app opens on the login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = await Session.load();

    await tester.pumpWidget(EmployeeApp(session: session));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
