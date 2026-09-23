import 'package:flutter_test/flutter_test.dart';

import 'package:ajyal_flame_showcase/main.dart';

void main() {
  testWidgets('Game hub renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AjyalApp());
    expect(find.text('أجيال الصالحية'), findsOneWidget);
  });
}
