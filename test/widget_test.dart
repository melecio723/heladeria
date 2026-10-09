import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_creditos/main.dart';

void main() {
  testWidgets('App carga sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const GestorCreditosApp());
    await tester.pump();
    expect(find.byType(GestorCreditosApp), findsOneWidget);
  });
}
