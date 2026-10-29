import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesa_checkout/pesa_checkout.dart';
import 'package:pesa_checkout/src/widgets/brand_mark.dart';

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

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
  }

  Finder field(int i) => find.byType(TextField).at(i);

  CardBrand? shownBrand(WidgetTester t) {
    final marks = find.byType(CardBrandMark);
    return marks.evaluate().isEmpty ? null : t.widget<CardBrandMark>(marks.last).brand;
  }

  BorderSide ring(WidgetTester t, int i) {
    final box = t.widget<AnimatedContainer>(find.ancestor(of: field(i), matching: find.byType(AnimatedContainer)).first);
    return (box.foregroundDecoration! as BoxDecoration).border!.top;
  }

  testWidgets('number is grouped and the brand shown; form completes', (t) async {
    await pump(t);
    expect(controller.isComplete, isFalse);
    expect(find.widgetWithText(FilledButton, 'Pay'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await t.enterText(field(0), '4111111111111111');
    await t.pump();
    expect(controller.number.text, '4111 1111 1111 1111');
    expect(find.text('VISA'), findsOneWidget);

    await t.enterText(field(1), '1228');
    await t.enterText(field(2), '123');
    await t.enterText(field(3), 'Jo Bloggs');
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

  testWidgets('brand mark from the first digit, outline when ruled out', (t) async {
    await pump(t);
    expect(shownBrand(t), isNull);

    await t.enterText(field(0), '5');
    await settle(t);
    expect(shownBrand(t), CardBrand.mastercard);

    await t.enterText(field(0), '56');
    await settle(t);
    expect(shownBrand(t), isNull);

    await t.enterText(field(0), '4');
    await settle(t);
    expect(shownBrand(t), CardBrand.visa);

    await t.enterText(field(0), '34');
    await settle(t);
    expect(shownBrand(t), CardBrand.amex);
  });

  testWidgets('expiry adds the slash after the month', (t) async {
    await pump(t);
    await t.enterText(field(1), '3');
    expect(controller.expiry.text, '03/');
    await t.enterText(field(1), '');
    await t.enterText(field(1), '12');
    expect(controller.expiry.text, '12/');
  });

  testWidgets('errors sit on a reserved line and nothing moves', (t) async {
    await pump(t);
    final expiryTop = t.getTopLeft(field(1)).dy;
    final holderTop = t.getTopLeft(field(3)).dy;

    await t.enterText(field(0), '4111111111111112');
    await settle(t);
    expect(find.text("This card number isn't valid. Check it and try again."), findsOneWidget);
    expect(t.getTopLeft(field(1)).dy, expiryTop);

    await t.enterText(field(1), '1320');
    await settle(t);
    expect(find.text('Enter a month from 01 to 12.'), findsOneWidget);
    expect(t.getTopLeft(field(3)).dy, holderTop);
    expect(t.getTopLeft(field(2)).dy, t.getTopLeft(field(1)).dy);
  });

  testWidgets('leaving an empty field shows no error; leaving a partial one does', (t) async {
    await pump(t);
    await t.tap(field(0));
    await t.tap(field(3));
    await settle(t);
    expect(find.text('Enter the card number.'), findsNothing);

    await t.enterText(field(0), '4111');
    await t.tap(field(3));
    await settle(t);
    expect(find.text('Card number is incomplete.'), findsOneWidget);
  });

  testWidgets('the focused field gets a ring', (t) async {
    await pump(t);
    expect(ring(t, 0).width, 0);
    await t.tap(field(0));
    await settle(t);
    expect(ring(t, 0).width, 1.5);
    expect(ring(t, 1).width, 0);
  });

  testWidgets('email is required only when asked', (t) async {
    await pump(t, needsEmail: true);
    expect(find.byType(TextField), findsNWidgets(5));
    await t.enterText(field(0), '5555555555554444');
    await t.enterText(field(1), '1228');
    await t.enterText(field(2), '123');
    await t.enterText(field(3), 'Jo Bloggs');
    await t.pump();
    expect(controller.isComplete, isFalse);
    await t.enterText(field(4), 'jo@example.com');
    await t.pump();
    expect(controller.isComplete, isTrue);
    expect(controller.emailText, 'jo@example.com');
  });

  testWidgets('security code is obscured and the number cannot be selected', (t) async {
    await pump(t);
    final cvv = t.widget<TextField>(field(2));
    expect(cvv.obscureText, isTrue);
    final number = t.widget<TextField>(field(0));
    expect(number.enableInteractiveSelection, isFalse);
    expect(number.enableSuggestions, isFalse);
  });
}
