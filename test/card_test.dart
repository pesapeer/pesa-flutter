import 'package:flutter_test/flutter_test.dart';
import 'package:pesa_checkout/pesa_checkout.dart';

void main() {
  group('brand detection', () {
    test('by prefix', () {
      expect(CardBrand.detect('4111111111111111'), CardBrand.visa);
      expect(CardBrand.detect('5555555555554444'), CardBrand.mastercard);
      expect(CardBrand.detect('2221000000000009'), CardBrand.mastercard);
      expect(CardBrand.detect('378282246310005'), CardBrand.amex);
      expect(CardBrand.detect('6200000000000005'), CardBrand.unionpay);
      expect(CardBrand.detect('9'), CardBrand.unknown);
      expect(CardBrand.detect(''), CardBrand.unknown);
    });

    test('gateway codes', () {
      expect(CardBrand.visa.code, 'visa');
      expect(CardBrand.unknown.code, 'card');
    });
  });

  group('number', () {
    test('accepts the Tribe test cards', () {
      for (final n in ['4111111111111111', '4012888888881881', '5555555555554444', '5105105105105100', '378282246310005']) {
        expect(CardValidation.number(n), isNull, reason: n);
      }
    });

    test('accepts spaces', () {
      expect(CardValidation.number('4111 1111 1111 1111'), isNull);
    });

    test('rejects a failed Luhn, a short number and letters', () {
      expect(CardValidation.number('4111111111111112'), isNotNull);
      expect(CardValidation.number('41111111'), isNotNull);
      expect(CardValidation.number('4111 1111 1111 111a'), isNotNull);
      expect(CardValidation.number(''), isNotNull);
    });

    test('formats in groups', () {
      expect(CardValidation.format('4111111111111111', CardBrand.visa), '4111 1111 1111 1111');
      expect(CardValidation.format('378282246310005', CardBrand.amex), '3782 822463 10005');
      expect(CardValidation.format('41', CardBrand.visa), '41');
    });
  });

  group('expiry', () {
    final now = DateTime(2026, 10, 24);

    test('parses MM/YY and MMYYYY', () {
      expect(CardExpiry.parse('12/28')?.year, 2028);
      expect(CardExpiry.parse('12/28')?.month, 12);
      expect(CardExpiry.parse('012028')?.year, 2028);
      expect(CardExpiry.parse('1228')?.month, 12);
      expect(CardExpiry.parse('13/28'), isNull);
      expect(CardExpiry.parse('1/28'), isNull);
    });

    test('current month is valid, last month is not', () {
      expect(CardValidation.expiry('10/26', now: now), isNull);
      expect(CardValidation.expiry('09/26', now: now), 'This card has expired.');
      expect(CardValidation.expiry('1/2', now: now), 'Enter the expiry as MM/YY.');
      expect(CardValidation.expiry('13/28', now: now), 'Enter a month from 01 to 12.');
      expect(CardValidation.expiry('12/49', now: now), 'Check the expiry year.');
    });
  });

  group('security code and holder', () {
    test('length by brand', () {
      expect(CardValidation.securityCode('123', CardBrand.visa), isNull);
      expect(CardValidation.securityCode('1234', CardBrand.visa), isNotNull);
      expect(CardValidation.securityCode('1234', CardBrand.amex), isNull);
      expect(CardValidation.securityCode('123', CardBrand.unknown), isNull);
      expect(CardValidation.securityCode('12a', CardBrand.visa), isNotNull);
    });

    test('holder 3-26', () {
      expect(CardValidation.holderName('Jo'), isNotNull);
      expect(CardValidation.holderName('Jo Bloggs'), isNull);
      expect(CardValidation.holderName('A' * 27), isNotNull);
    });
  });

  test('CardDetails strips spaces and exposes last4', () {
    final c = CardDetails(number: '4111 1111 1111 1111', expiry: const CardExpiry(12, 2028), securityCode: ' 000 ', holderName: ' Jo Bloggs ');
    expect(c.number, '4111111111111111');
    expect(c.last4, '1111');
    expect(c.brand, CardBrand.visa);
    expect(c.securityCode, '000');
    expect(c.holderName, 'Jo Bloggs');
  });
}
