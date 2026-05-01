import 'package:flutter_test/flutter_test.dart';

import 'package:transporter_mobile/main.dart';

void main() {
  testWidgets('app renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TransporterApp());
    expect(find.text('Cadastro simples'), findsOneWidget);
  });
}
