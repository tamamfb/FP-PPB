import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app.dart';
import 'package:myapp/providers/user_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const MyApp(),
      ),
    );
    expect(find.text('TriLearn'), findsWidgets);
  });
}
