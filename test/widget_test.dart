import 'package:flutter_test/flutter_test.dart';

import 'package:military_app/main.dart';

void main() {
  testWidgets('login screen renders expected fields', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Package Tracking'), findsOneWidget);
    expect(find.text('User Name'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
