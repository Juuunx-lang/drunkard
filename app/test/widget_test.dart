import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drunkard/app.dart';

void main() {
  testWidgets('shows login screen when no session exists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: DrunkardApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DRUNKARD'), findsOneWidget);
    expect(find.text('开发模式登录'), findsOneWidget);
  });
}
