// material_ui needs Flutter 3.47; this package supports 3.35.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesa_checkout/src/challenge.dart';
import 'package:pesa_checkout/src/l10n/pesa_checkout_strings.dart';

void main() {
  final returnUrl = Uri.parse('https://checkout.test/c/int_1/return');

  ChallengeNavigation decide(String url, {bool isMainFrame = true}) =>
      challengeNavigation(Uri.parse(url), isMainFrame: isMainFrame, returnUrl: returnUrl);

  test('the issuer\'s pages load', () {
    expect(decide('https://acs.bank.test/challenge'), ChallengeNavigation.load);
    expect(decide('https://acs.bank.test/method', isMainFrame: false), ChallengeNavigation.load);
  });

  test('the return page ends the challenge in any frame', () {
    expect(decide('https://checkout.test/c/int_1/return'), ChallengeNavigation.finish);
    expect(decide('https://checkout.test/c/int_1/return/?cres=x'), ChallengeNavigation.finish);
    expect(decide('https://checkout.test/c/int_1/return', isMainFrame: false), ChallengeNavigation.finish);
  });

  test('the page leaving for the app\'s scheme ends the challenge', () {
    expect(decide('pesapeer://ipg-return'), ChallengeNavigation.finish);
  });

  test('3-D Secure iframes do not end the challenge', () {
    for (final url in ['about:blank', 'about:srcdoc', 'data:text/html,', 'blob:https://acs.bank.test/1']) {
      expect(decide(url, isMainFrame: false), ChallengeNavigation.load, reason: url);
    }
  });

  test('an iframe cannot open another app or end the challenge', () {
    expect(decide('bankapp://approve', isMainFrame: false), ChallengeNavigation.block);
  });

  group('the page around the bank', () {
    Future<List<String>> pump(
      WidgetTester tester, {
      String? title,
      bool connecting = false,
      PesaCheckoutStrings strings = PesaCheckoutStrings.en,
    }) async {
      final cancelled = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: ChallengeChrome(
          strings: strings,
          title: title,
          loading: connecting,
          connecting: connecting,
          onCancel: () => cancelled.add('cancelled'),
          child: const Text('the bank'),
        ),
      ));
      return cancelled;
    }

    testWidgets('has no title of its own, and a name for screen readers', (tester) async {
      await pump(tester);

      expect(find.descendant(of: find.byType(AppBar), matching: find.byType(Text)), findsNothing);
      expect(find.bySemanticsLabel('Bank verification'), findsOneWidget);
      expect(find.text('the bank'), findsOneWidget);
    });

    testWidgets('shows the title a merchant gives it', (tester) async {
      await pump(tester, title: 'Approve payment');

      expect(find.widgetWithText(AppBar, 'Approve payment'), findsOneWidget);
    });

    testWidgets('says it is connecting until the bank\'s page is up', (tester) async {
      await pump(tester, connecting: true);
      expect(find.text('Connecting to your bank…'), findsOneWidget);

      await pump(tester);
      expect(find.text('Connecting to your bank…'), findsNothing);
    });

    testWidgets('closing asks first, and keeping going cancels nothing', (tester) async {
      final cancelled = await pump(tester);

      await tester.tap(find.byTooltip('Cancel payment'));
      await tester.pump();
      expect(find.text('Cancel this payment?'), findsOneWidget);
      expect(cancelled, isEmpty);

      await tester.tap(find.text('Keep going'));
      await tester.pump();
      expect(find.text('Cancel this payment?'), findsNothing);
      expect(cancelled, isEmpty);
    });

    testWidgets('confirming cancels the payment', (tester) async {
      final cancelled = await pump(tester);

      await tester.tap(find.byTooltip('Cancel payment'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel payment'));

      expect(cancelled, ['cancelled']);
    });

    testWidgets('the system back button asks too', (tester) async {
      final cancelled = await pump(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Cancel this payment?'), findsOneWidget);
      expect(cancelled, isEmpty);
    });

    testWidgets('speaks the form\'s language', (tester) async {
      await pump(tester, connecting: true, strings: PesaCheckoutStrings.fr);
      expect(find.text('Connexion à votre banque…'), findsOneWidget);

      await tester.tap(find.byTooltip('Annuler le paiement'));
      await tester.pump();
      expect(find.text('Annuler ce paiement ?'), findsOneWidget);
    });
  });
}
