/// Card details and the checks the form runs before anything is sent.
library;

enum CardBrand {
  visa('visa', 'Visa', 16, 16, 3),
  mastercard('mastercard', 'Mastercard', 16, 16, 3),
  amex('amex', 'American Express', 15, 15, 4),
  unionpay('unionpay', 'UnionPay', 16, 19, 3),
  unknown('card', 'Card', 13, 19, 3);

  const CardBrand(
    this.code,
    this.label,
    this.minLength,
    this.maxLength,
    this.cvvLength,
  );

  /// The gateway's name for the brand.
  final String code;
  final String label;
  final int minLength;
  final int maxLength;
  final int cvvLength;

  /// The brand for a gateway code; [unknown] when there is none.
  static CardBrand fromCode(String code) =>
      values.firstWhere((b) => b.code == code, orElse: () => unknown);

  /// Detects the brand from the digits typed so far.
  static CardBrand detect(String digits) {
    if (digits.isEmpty) return unknown;
    if (digits.startsWith('4')) return visa;
    if (digits.length >= 2) {
      final two = int.parse(digits.substring(0, 2));
      if (two == 34 || two == 37) return amex;
      if (two >= 51 && two <= 55) return mastercard;
      if (two == 62) return unionpay;
    }
    if (digits.length >= 4) {
      final four = int.parse(digits.substring(0, 4));
      if (four >= 2221 && four <= 2720) return mastercard;
    }
    return unknown;
  }

  /// Where spaces go when the number is shown: 4-6-5 for Amex, 4-4-4-4
  /// otherwise.
  List<int> get groups =>
      this == amex ? const [4, 6, 5] : const [4, 4, 4, 4, 3];
}

/// A card expiry, month and four-digit year.
class CardExpiry {
  const CardExpiry(this.month, this.year);

  final int month;
  final int year;

  /// Parses "MM/YY", "MM/YYYY", "MMYY" or "MMYYYY".
  static CardExpiry? parse(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 4 && digits.length != 6) return null;
    final month = int.parse(digits.substring(0, 2));
    var year = int.parse(digits.substring(2));
    if (digits.length == 4) year += 2000;
    if (month < 1 || month > 12) return null;
    return CardExpiry(month, year);
  }

  /// Whether the card is still valid in the month of [now].
  bool isValidAt(DateTime now) =>
      year > now.year || (year == now.year && month >= now.month);
}

/// What the cardholder typed. Lives in memory until [PesaCheckout.payWithCard]
/// has sent it; call [clear] afterwards.
class CardDetails {
  CardDetails({
    required String number,
    required this.expiry,
    required String securityCode,
    required String holderName,
  })  : number = number.replaceAll(RegExp(r'\s'), ''),
        securityCode = securityCode.trim(),
        holderName = holderName.trim();

  final String number;
  final CardExpiry expiry;
  final String securityCode;
  final String holderName;

  CardBrand get brand => CardBrand.detect(number);
  String get last4 => number.length >= 4 ? number.substring(number.length - 4) : number;
}

/// The checks the form applies. They mirror the gateway's; the gateway's
/// answer is the one that counts.
class CardValidation {
  CardValidation._();

  static bool allDigits(String s) =>
      s.isNotEmpty && s.codeUnits.every((c) => c >= 0x30 && c <= 0x39);

  static bool luhn(String digits) {
    if (!allDigits(digits)) return false;
    var sum = 0;
    var double = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits.codeUnitAt(i) - 0x30;
      if (double) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      double = !double;
    }
    return sum % 10 == 0;
  }

  /// Null when the number is acceptable, else a message for the field.
  static String? number(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s'), '');
    if (digits.isEmpty) return 'Enter the card number.';
    if (!allDigits(digits)) return 'Digits only.';
    final brand = CardBrand.detect(digits);
    if (digits.length < brand.minLength) return 'Card number is incomplete.';
    if (digits.length > brand.maxLength || !luhn(digits)) {
      return "This card number isn't valid. Check it and try again.";
    }
    return null;
  }

  static String? expiry(String raw, {DateTime? now}) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 4 && digits.length != 6) return 'Enter the expiry as MM/YY.';
    final parsed = CardExpiry.parse(digits);
    if (parsed == null) return 'Enter a month from 01 to 12.';
    final today = now ?? DateTime.now();
    if (!parsed.isValidAt(today)) return 'This card has expired.';
    if (parsed.year > today.year + 20) return 'Check the expiry year.';
    return null;
  }

  static String? securityCode(String raw, CardBrand brand) {
    final ok = allDigits(raw) &&
        (raw.length == brand.cvvLength || (brand == CardBrand.unknown && (raw.length == 3 || raw.length == 4)));
    if (ok) return null;
    return switch (brand) {
      CardBrand.amex => 'Enter the 4-digit code on the front.',
      CardBrand.unknown => 'Enter the security code.',
      _ => 'Enter the ${brand.cvvLength}-digit code on the back.',
    };
  }

  static String? holderName(String raw) {
    final name = raw.trim();
    if (name.length < 3 || name.length > 26) return 'Enter the name as printed, 3 to 26 characters.';
    return null;
  }

  static String? email(String raw) {
    final e = raw.trim();
    if (e.isEmpty || !e.contains('@') || e.length > 50) return 'Enter an email address.';
    return null;
  }

  /// Groups the digits with spaces for display.
  static String format(String digits, CardBrand brand) {
    final buf = StringBuffer();
    var i = 0;
    for (final g in brand.groups) {
      if (i >= digits.length) break;
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(digits.substring(i, (i + g).clamp(0, digits.length)));
      i += g;
    }
    return buf.toString();
  }
}
