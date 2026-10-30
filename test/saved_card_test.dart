import 'package:flutter_test/flutter_test.dart';
import 'package:pesa_checkout/pesa_checkout.dart';

const visa = SavedCard(token: 'tok_visa', brand: 'visa', last4: '4242', expiry: '12/2099', holderName: 'A Payer');
const amex = SavedCard(token: 'tok_amex', brand: 'amex', last4: '0005', expiry: '01/2099');
const expired = SavedCard(token: 'tok_old', brand: 'mastercard', last4: '4444', expiry: '01/2020');

CheckoutSession session({
  List<SavedCard> cards = const [visa, amex],
  SavedCardSecurityCode code = SavedCardSecurityCode.optional,
  bool canSaveCard = true,
}) =>
    CheckoutSession(
      intentId: 'int_1',
      state: 'open',
      amount: '25.00',
      currency: 'GBP',
      canSaveCard: canSaveCard,
      savedCards: cards,
      savedCardSecurityCode: code,
    );

void main() {
  group('models', () {
    test('a session without saved cards', () {
      final s = CheckoutSession.fromJson({'intentId': 'int_1', 'state': 'open'});
      expect(s.canSaveCard, isFalse);
      expect(s.savedCards, isEmpty);
      expect(s.savedCardSecurityCode, SavedCardSecurityCode.optional);
    });

    test('saved cards without a token are dropped', () {
      final s = CheckoutSession.fromJson({
        'savedCards': [
          {'token': 'tok_1', 'brand': 'mastercard', 'last4': '4444', 'expiry': '03/2030'},
          {'brand': 'visa', 'last4': '4242'},
          'not a card',
        ],
        'savedCardSecurityCode': 'never',
      });
      expect(s.savedCards.map((c) => c.token), ['tok_1']);
      expect(s.savedCards.single.cardBrand, CardBrand.mastercard);
      expect(s.savedCards.single.parsedExpiry?.month, 3);
      expect(s.savedCards.single.parsedExpiry?.year, 2030);
      expect(s.savedCardSecurityCode, SavedCardSecurityCode.never);
    });

    test('security code rule', () {
      expect(SavedCardSecurityCode.parse('required'), SavedCardSecurityCode.required);
      expect(SavedCardSecurityCode.parse('optional'), SavedCardSecurityCode.optional);
      expect(SavedCardSecurityCode.parse('never'), SavedCardSecurityCode.never);
      expect(SavedCardSecurityCode.parse('sometimes'), SavedCardSecurityCode.optional);
      expect(SavedCardSecurityCode.parse(null), SavedCardSecurityCode.optional);
    });

    test('brand from the gateway code', () {
      expect(CardBrand.fromCode('amex'), CardBrand.amex);
      expect(CardBrand.fromCode('unionpay'), CardBrand.unionpay);
      expect(CardBrand.fromCode('diners'), CardBrand.unknown);
    });

    test('expired and unreadable expiries', () {
      final now = DateTime(2026, 10, 30);
      expect(visa.isUsableAt(now), isTrue);
      expect(expired.isUsableAt(now), isFalse);
      expect(const SavedCard(token: 't', expiry: '10/2026').isUsableAt(now), isTrue);
      expect(const SavedCard(token: 't', expiry: '').isUsableAt(now), isTrue);
    });

    test('toString leaves the token out', () {
      expect(visa.toString(), isNot(contains('tok_visa')));
      expect(visa.toString(), contains('4242'));
    });
  });

  group('form controller', () {
    late PesaCardFormController form;

    setUp(() => form = PesaCardFormController());
    tearDown(() => form.dispose());

    test('selects the first card that has not expired', () {
      form.useSession(session(cards: const [expired, amex, visa]));
      expect(form.savedCard?.token, 'tok_amex');
      expect(form.brand, CardBrand.amex);
      expect(form.details(), isNull);
    });

    test('no usable card leaves the typed card selected', () {
      form.useSession(session(cards: const [expired]));
      expect(form.savedCard, isNull);
      expect(form.savedCards, hasLength(1));
    });

    test('optional: complete without a code, incomplete with a partial one', () {
      form.useSession(session());
      expect(form.isComplete, isTrue);
      expect(form.savedCardCvv, isNull);
      form.cvv.text = '12';
      expect(form.isComplete, isFalse);
      form.cvv.text = '123';
      expect(form.isComplete, isTrue);
      expect(form.savedCardCvv, '123');
    });

    test('required: needs the code for the card brand', () {
      form.useSession(session(cards: const [amex], code: SavedCardSecurityCode.required));
      expect(form.isComplete, isFalse);
      form.cvv.text = '123';
      expect(form.isComplete, isFalse);
      form.cvv.text = '1234';
      expect(form.isComplete, isTrue);
      expect(form.savedCardCvv, '1234');
    });

    test('never: complete, and no code is handed out', () {
      form.useSession(session(code: SavedCardSecurityCode.never));
      form.cvv.text = '123';
      expect(form.isComplete, isTrue);
      expect(form.savedCardCvv, isNull);
    });

    test('changing the selection empties the code', () {
      form.useSession(session());
      form.cvv.text = '123';
      form.selectSavedCard(amex);
      expect(form.cvv.text, '');
      form.cvv.text = '1234';
      form.selectSavedCard(null);
      expect(form.cvv.text, '');
      expect(form.savedCard, isNull);
      expect(form.isComplete, isFalse);
    });

    test('another card: typed details, and the save flag', () {
      form.useSession(session());
      form.saveCard = true;
      expect(form.saveCard, isFalse);
      form.selectSavedCard(null);
      expect(form.saveCard, isTrue);
      form.number.text = '4111 1111 1111 1111';
      form.expiry.text = '12/30';
      form.cvv.text = '123';
      form.holder.text = 'Jo Bloggs';
      expect(form.isComplete, isTrue);
      expect(form.details()?.number, '4111111111111111');
      expect(form.savedCardCvv, isNull);
    });

    test('the save flag is off when the session does not offer it', () {
      form.useSession(session(cards: const [], canSaveCard: false));
      form.saveCard = true;
      expect(form.canSaveCard, isFalse);
      expect(form.saveCard, isFalse);
    });

    test('clear empties the code and keeps the selection', () {
      form.useSession(session());
      form.cvv.text = '123';
      form.clear();
      expect(form.cvv.text, '');
      expect(form.savedCard?.token, 'tok_visa');
    });
  });
}
