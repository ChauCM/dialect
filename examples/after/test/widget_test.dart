import 'package:flutter_test/flutter_test.dart';

import 'package:after/main.dart';

void main() {
  testWidgets('home screen renders', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Your trips'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });
}
