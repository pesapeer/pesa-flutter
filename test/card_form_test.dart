import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesa_checkout/pesa_checkout.dart';

void main() {
  late PesaCardFormController controller;

  setUp(() => controller = PesaCardFormController());
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester t, {bool needsEmail = false}) => t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            PesaCardForm(controller: controller, needsEmail: needsEmail),
            PesaPayButton(controller: controller, label: 'Pay', onPressed: () {}),
          ]),
        ),
      ));

  testWidgets('number is grouped and the brand shown; form completes', (t) async {
    await pump(t);
    expect(controller.isComplete, isFalse);
    expect(find.widgetWithText(FilledButton, 'Pay'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await t.enterText(find.byType(TextField).at(0), '4111111111111111');
    await t.pump();
    expect(controller.number.text, '4111 1111 1111 1111');
    expect(find.text('Visa'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(1), '1228');
    await t.enterText(find.byType(TextField).at(2), '123');
    await t.enterText(find.byType(TextField).at(3), 'Jo Bloggs');
    await t.pump();
    expect(controller.expiry.text, '12/28');
    expect(controller.isComplete, isTrue);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);

    final d = controller.details()!;
    expect(d.number, '4111111111111111');
    expect(d.expiry.year, 2028);

    controller.clear();
    expect(controller.number.text, '');
    expect(controller.cvv.text, '');
    expect(controller.isComplete, isFalse);
  });

  testWidgets('email is required only when asked', (t) async {
    await pump(t, needsEmail: true);
    expect(find.byType(TextField), findsNWidgets(5));
    await t.enterText(find.byType(TextField).at(0), '5555555555554444');
    await t.enterText(find.byType(TextField).at(1), '1228');
    await t.enterText(find.byType(TextField).at(2), '123');
    await t.enterText(find.byType(TextField).at(3), 'Jo Bloggs');
    await t.pump();
    expect(controller.isComplete, isFalse);
    await t.enterText(find.byType(TextField).at(4), 'jo@example.com');
    await t.pump();
    expect(controller.isComplete, isTrue);
    expect(controller.emailText, 'jo@example.com');
  });

  testWidgets('security code is obscured and the number cannot be selected', (t) async {
    await pump(t);
    final cvv = t.widget<TextField>(find.byType(TextField).at(2));
    expect(cvv.obscureText, isTrue);
    final number = t.widget<TextField>(find.byType(TextField).at(0));
    expect(number.enableInteractiveSelection, isFalse);
    expect(number.enableSuggestions, isFalse);
  });
}
