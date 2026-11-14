import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resqdrive/main.dart';
import 'package:resqdrive/providers/app_provider.dart';

void main() {
  testWidgets('RESQDRIVE app builds', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(create: (_) => AppProvider()..isInitializing = false, child: const ResqDriveApp()));
    expect(find.text('RESQDRIVE'), findsOneWidget);
  });
}
