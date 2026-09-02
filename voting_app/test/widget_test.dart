import 'package:flutter_test/flutter_test.dart';

import 'package:voting_app/main.dart';

void main() {
  testWidgets('App boots to login', (WidgetTester tester) async {
    await tester.pumpWidget(const VotingApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('NovaVote'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsWidgets);
  });
}
