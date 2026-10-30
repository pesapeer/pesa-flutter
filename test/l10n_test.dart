import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pesa_checkout/pesa_checkout.dart';
import 'package:pesa_checkout/src/l10n/strings_en.dart';
import 'package:pesa_checkout/src/l10n/strings_fr.dart';
import 'package:pesa_checkout/src/l10n/strings_fr_ca.dart';
import 'package:pesa_checkout/src/l10n/strings_zh_hans.dart';

final nnbsp = String.fromCharCode(0x202F);

void main() {
  group('maps', () {
    final maps = {'fr': stringsFr, 'fr-CA': {...stringsFr, ...stringsFrCa}, 'zh-Hans': stringsZhHans};

    for (final MapEntry(key: tag, value: map) in maps.entries) {
      test('$tag has the same keys as en', () {
        expect(map.keys.toSet(), stringsEn.keys.toSet());
      });

      test('$tag keeps every placeholder of en', () {
        final placeholder = RegExp(r'\{\w+\}');
        for (final key in stringsEn.keys) {
          final want = placeholder.allMatches(stringsEn[key]!).map((m) => m[0]).toSet();
          final got = placeholder.allMatches(map[key]!).map((m) => m[0]).toSet();
          expect(got, want, reason: '$tag $key');
        }
      });
    }

    test('fr-CA overrides only keys that exist', () {
      expect(stringsEn.keys, containsAll(stringsFrCa.keys));
    });

    test('fr-CA inherits fr and uses Québec words', () {
      final s = PesaCheckoutStrings.frCA;
      expect(s.cardNumber, PesaCheckoutStrings.fr.cardNumber);
      expect(s.email, 'Courriel pour votre reçu');
      expect(s.brandName(CardBrand.unknown), 'Carte de crédit ou de débit');
      expect(s.brandName(CardBrand.visa), 'Visa');
    });
  });

  group('resolution', () {
    test('close tags map to a supported one', () {
      expect(PesaCheckoutStrings.supportedTag('en-GB'), 'en');
      expect(PesaCheckoutStrings.supportedTag('fr'), 'fr');
      expect(PesaCheckoutStrings.supportedTag('fr-BE'), 'fr');
      expect(PesaCheckoutStrings.supportedTag('fr_CA'), 'fr-CA');
      expect(PesaCheckoutStrings.supportedTag('fr-Latn-CA'), 'fr-CA');
      expect(PesaCheckoutStrings.supportedTag('zh'), 'zh-Hans');
      expect(PesaCheckoutStrings.supportedTag('zh-CN'), 'zh-Hans');
      expect(PesaCheckoutStrings.supportedTag('zh-Hant-TW'), 'zh-Hans');
      expect(PesaCheckoutStrings.supportedTag('de-DE'), isNull);
      expect(PesaCheckoutStrings.supportedTag(null), isNull);
    });

    test('an unsupported tag falls back to English', () {
      expect(PesaCheckoutStrings.resolve('de').tag, 'en');
      expect(PesaCheckoutStrings.resolve(null).tag, 'en');
    });

    test('host locale, then session, then device, then English', () {
      String pick({Locale? locale, String? session, Locale? device}) =>
          PesaCheckoutStrings.pick(locale: locale, sessionLocale: session, device: device).tag;
      const fr = Locale('fr');
      const zh = Locale('zh');
      expect(pick(locale: zh, session: 'fr', device: const Locale('en')), 'zh-Hans');
      expect(pick(locale: const Locale('de'), session: 'fr-CA', device: zh), 'fr-CA');
      expect(pick(session: 'xx', device: fr), 'fr');
      expect(pick(device: const Locale('fr', 'CA')), 'fr-CA');
      expect(pick(device: const Locale('ja')), 'en');
    });

    test('the delegate loads the matching strings', () async {
      const d = PesaCheckoutLocalizations.delegate;
      expect(d.isSupported(const Locale('fr', 'BE')), isTrue);
      expect(d.isSupported(const Locale('de')), isFalse);
      expect((await d.load(const Locale('fr', 'CA'))).tag, 'fr-CA');
      expect(PesaCheckoutLocalizations.supportedLocales.map((l) => l.toLanguageTag()),
          ['en', 'fr', 'fr-CA', 'zh-Hans']);
    });
  });

  group('validation', () {
    final now = DateTime(2026, 10, 15);

    test('messages come out in the chosen language', () {
      const fr = PesaCheckoutStrings.fr;
      const zh = PesaCheckoutStrings.zhHans;
      expect(CardValidation.number('', strings: fr), 'Saisissez le numéro de carte.');
      expect(CardValidation.number('4111111111111112', strings: zh), '卡号无效，请检查后重试。');
      expect(CardValidation.expiry('09/26', now: now, strings: fr), 'Cette carte a expiré.');
      expect(CardValidation.expiry('1/2', now: now, strings: fr), 'Saisissez la date d’expiration au format MM/AA.');
      expect(CardValidation.securityCode('12', CardBrand.visa, strings: fr),
          'Saisissez le code à 3 chiffres au verso de la carte.');
      expect(CardValidation.securityCode('12', CardBrand.amex, strings: zh), '请输入卡片正面的 4 位安全码。');
      expect(CardValidation.email('x', strings: PesaCheckoutStrings.frCA), 'Saisissez une adresse courriel.');
      expect(CardValidation.holderName('Jo', strings: zh), '请按卡面所印输入姓名，3 至 26 个字符。');
    });

    test('English stays the default', () {
      expect(CardValidation.expiry('09/26', now: now), 'This card has expired.');
      expect(CardValidation.securityCode('12', CardBrand.visa), 'Enter the 3-digit code on the back.');
    });
  });

  group('money', () {
    test('each locale writes the amount its own way', () {
      expect(PesaCheckoutStrings.en.money('2.00', 'GBP'), '£2.00');
      expect(PesaCheckoutStrings.zhHans.money('2.00', 'gbp'), '£2.00');
      expect(PesaCheckoutStrings.fr.money('2.00', 'GBP'), '2,00$nnbsp£');
      expect(PesaCheckoutStrings.frCA.money('2.00', 'GBP'), '2,00$nnbsp£');
      expect(PesaCheckoutStrings.en.money('1234567.5', 'EUR'), '€1,234,567.5');
      expect(PesaCheckoutStrings.fr.money('1234.50', 'EUR'), '1${nnbsp}234,50$nnbsp€');
      expect(PesaCheckoutStrings.frCA.money('10.00', 'CAD'), '10,00$nnbsp\$');
      expect(PesaCheckoutStrings.en.money('500', 'KES'), 'KES${String.fromCharCode(0xA0)}500');
    });

    test('the pay text', () {
      expect(PesaCheckoutStrings.en.payAmount('25.00', 'GBP'), 'Pay £25.00');
      expect(PesaCheckoutStrings.fr.payAmount('25.00', 'GBP'), 'Payer 25,00$nnbsp£');
      expect(PesaCheckoutStrings.zhHans.payAmount('25.00', 'CNY'), '支付 ¥25.00');
    });
  });

  group('errors', () {
    test('known codes get the SDK text, unknown ones the fallback', () {
      const fr = PesaCheckoutStrings.fr;
      expect(fr.errorMessage('rate_limited'), 'Trop de tentatives. Patientez quelques instants, puis réessayez.');
      expect(fr.errorMessage('something_new', fallback: 'Gateway sentence.'), 'Gateway sentence.');
      expect(fr.errorMessage('http_500'), 'Le paiement n’a pas pu aboutir. Réessayez.');
    });

    test('the client localises the message and keeps the code and the gateway text', () async {
      final c = PesaCheckout(
        locale: const Locale('fr'),
        httpClient: MockClient((_) async =>
            http.Response(jsonEncode({'error': {'code': 'not_found', 'message': 'This payment link is not valid.'}}), 404)),
      );
      await expectLater(
        c.session('int_1', 'cs_x'),
        throwsA(isA<PesaCheckoutException>()
            .having((e) => e.code, 'code', 'not_found')
            .having((e) => e.message, 'message', PesaCheckoutStrings.fr.errorMessage('not_found'))
            .having((e) => e.detail, 'detail', 'This payment link is not valid.')),
      );
    });

    test('the client follows the session locale', () async {
      var calls = 0;
      final c = PesaCheckout(
        httpClient: MockClient((_) async {
          if (calls++ == 0) {
            return http.Response(jsonEncode({'intentId': 'int_1', 'state': 'open', 'locale': 'zh-Hans'}), 200);
          }
          throw http.ClientException('connection reset');
        }),
      );
      final s = await c.session('int_1', 'cs_x');
      expect(s.locale, 'zh-Hans');
      await expectLater(
        c.session('int_1', 'cs_x'),
        throwsA(isA<PesaCheckoutException>()
            .having((e) => e.code, 'code', 'transport')
            .having((e) => e.message, 'message', PesaCheckoutStrings.zhHans.errorMessage('transport'))
            .having((e) => e.detail, 'detail', 'connection reset')),
      );
    });
  });

  group('widgets', () {
    testWidgets('the form and pay button follow the session locale', (t) async {
      final form = PesaCardFormController();
      addTearDown(form.dispose);
      form.useSession(const CheckoutSession(
        intentId: 'int_1',
        state: 'open',
        amount: '25.00',
        currency: 'GBP',
        locale: 'fr',
        savedCards: [SavedCard(token: 'tok_1', brand: 'visa', last4: '4242', expiry: '09/2099')],
      ));
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            PesaCardForm(controller: form),
            PesaPayButton(controller: form, amount: '25.00', currency: 'GBP', onPressed: () {}),
          ]),
        ),
      ));
      expect(find.text('Expire fin 09/99'), findsOneWidget);
      expect(find.text('Utiliser une autre carte'), findsOneWidget);
      expect(find.text('Payer 25,00$nnbsp£'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Visa se terminant par 4242, expire fin 09/99'),
        findsOneWidget,
      );
    });

    testWidgets('an explicit locale wins over the session', (t) async {
      final form = PesaCardFormController(locale: const Locale('zh'));
      addTearDown(form.dispose);
      form.useSession(const CheckoutSession(intentId: 'int_1', state: 'open', amount: '1', currency: 'GBP', locale: 'fr'));
      await t.pumpWidget(MaterialApp(home: Scaffold(body: PesaCardForm(controller: form))));
      expect(find.text('卡号'), findsOneWidget);

      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PesaCardForm(controller: form, locale: const Locale('fr', 'CA'), needsEmail: true)),
      ));
      expect(find.text('Courriel pour votre reçu'), findsOneWidget);
    });

    testWidgets('without a locale the form follows the app', (t) async {
      final form = PesaCardFormController();
      addTearDown(form.dispose);
      await t.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [PesaCheckoutLocalizations.delegate, _AnyMaterial(), _AnyWidgets()],
        home: Scaffold(body: PesaCardForm(controller: form)),
      ));
      expect(find.text('Numéro de carte'), findsOneWidget);
      expect(find.text('MM/AA'), findsOneWidget);
    });
  });
}

/// The default English Material text for any locale, so a French app can
/// build in a test without flutter_localizations.
class _AnyMaterial extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyMaterial();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) => DefaultMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_AnyMaterial old) => false;
}

class _AnyWidgets extends LocalizationsDelegate<WidgetsLocalizations> {
  const _AnyWidgets();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) => DefaultWidgetsLocalizations.load(locale);

  @override
  bool shouldReload(_AnyWidgets old) => false;
}
