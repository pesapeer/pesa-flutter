/// What the checkout edge says about an intent, and what the SDK reports.
library;

import 'card.dart';

enum WalletKind { applePay, googlePay }

class CheckoutMerchant {
  const CheckoutMerchant({this.displayName = '', this.logoUrl = '', this.supportUrl = ''});

  final String displayName;
  final String logoUrl;
  final String supportUrl;

  factory CheckoutMerchant.fromJson(Map<String, dynamic>? j) => j == null
      ? const CheckoutMerchant()
      : CheckoutMerchant(
          displayName: j['displayName'] as String? ?? '',
          logoUrl: j['logoUrl'] as String? ?? '',
          supportUrl: j['supportUrl'] as String? ?? '',
        );
}

/// The latest card attempt on the intent.
class CheckoutAttempt {
  const CheckoutAttempt({
    required this.state,
    this.challengeUrl,
    this.brand,
    this.last4,
    this.failureReason,
    this.declineCode,
  });

  /// pending, requires_3ds, authorized, captured, declined, failed,
  /// cancelled, refunded or unknown.
  final String state;
  final String? challengeUrl;
  final String? brand;
  final String? last4;
  final String? failureReason;
  final String? declineCode;

  bool get isPending => state == 'pending';
  bool get requires3ds => state == 'requires_3ds';
  bool get isSuccess => state == 'captured' || state == 'authorized';

  factory CheckoutAttempt.fromJson(Map<String, dynamic> j) {
    final card = j['card'] as Map<String, dynamic>?;
    return CheckoutAttempt(
      state: j['state'] as String? ?? 'unknown',
      challengeUrl: j['challengeUrl'] as String?,
      brand: card?['brand'] as String?,
      last4: card?['last4'] as String?,
      failureReason: j['failureReason'] as String?,
      declineCode: j['declineCode'] as String?,
    );
  }
}

/// Whether to ask the security code again for a saved card.
enum SavedCardSecurityCode {
  required,
  optional,
  never;

  /// [never] when the value is missing or unknown: no field is shown and
  /// no code is sent.
  static SavedCardSecurityCode parse(Object? value) =>
      values.firstWhere((v) => v.name == value, orElse: () => never);
}

/// A card the payer saved on an earlier payment. The acquirer keeps the
/// card; [token] stands for it.
class SavedCard {
  const SavedCard({
    required this.token,
    this.brand = '',
    this.last4 = '',
    this.expiry = '',
    this.holderName = '',
  });

  /// Opaque. Pass it to `PesaCheckout.payWithSavedCard` only; never log it.
  final String token;

  /// The gateway's brand code: visa, mastercard, amex, unionpay. Read in
  /// any case; see [CardBrand.fromCode].
  final String brand;
  final String last4;

  /// MM/YYYY.
  final String expiry;
  final String holderName;

  CardBrand get cardBrand => CardBrand.fromCode(brand);
  CardExpiry? get parsedExpiry => CardExpiry.parse(expiry);

  /// False once the card has expired. A card with an unreadable expiry is
  /// left to the gateway to judge.
  bool isUsableAt(DateTime now) => parsedExpiry?.isValidAt(now) ?? true;

  factory SavedCard.fromJson(Map<String, dynamic> j) => SavedCard(
        token: j['token'] as String? ?? '',
        brand: j['brand'] as String? ?? '',
        last4: j['last4'] as String? ?? '',
        expiry: j['expiry'] as String? ?? '',
        holderName: j['holderName'] as String? ?? '',
      );

  @override
  String toString() => 'SavedCard($brand •••• $last4)';
}

/// `checkoutSession` from the contract.
class CheckoutSession {
  const CheckoutSession({
    required this.intentId,
    required this.state,
    required this.amount,
    required this.currency,
    this.description = '',
    this.descriptor = '',
    this.merchant = const CheckoutMerchant(),
    this.methods = const ['card'],
    this.needsEmail = false,
    this.returnUrl,
    this.cancelUrl,
    this.attempt,
    this.expiresAt,
    this.canSaveCard = false,
    this.savedCards = const [],
    this.savedCardSecurityCode = SavedCardSecurityCode.never,
    this.locale,
  });

  final String intentId;

  /// open, authorized, settled, expired or cancelled.
  final String state;
  final String amount;
  final String currency;
  final String description;
  final String descriptor;
  final CheckoutMerchant merchant;
  final List<String> methods;
  final bool needsEmail;
  final String? returnUrl;
  final String? cancelUrl;
  final CheckoutAttempt? attempt;
  final DateTime? expiresAt;

  /// Whether the form may offer to keep the card. True when the intent
  /// names a customer.
  final bool canSaveCard;

  /// The payer's cards on file, most recently used first.
  final List<SavedCard> savedCards;
  final SavedCardSecurityCode savedCardSecurityCode;

  /// The language the merchant set on the intent: en, fr, fr-CA or
  /// zh-Hans. Null when not set; the SDK then follows the app and device.
  final String? locale;

  bool get isOpen => state == 'open';
  bool get isClosed => state == 'settled' || state == 'authorized' || state == 'expired' || state == 'cancelled';

  factory CheckoutSession.fromJson(Map<String, dynamic> j) {
    final attempt = j['attempt'];
    return CheckoutSession(
      intentId: j['intentId'] as String? ?? '',
      state: j['state'] as String? ?? 'open',
      amount: j['amount'] as String? ?? '',
      currency: j['currency'] as String? ?? '',
      description: j['description'] as String? ?? '',
      descriptor: j['descriptor'] as String? ?? '',
      merchant: CheckoutMerchant.fromJson(j['merchant'] as Map<String, dynamic>?),
      methods: (j['methods'] as List?)?.cast<String>() ?? const ['card'],
      needsEmail: j['needsEmail'] as bool? ?? false,
      returnUrl: j['returnUrl'] as String?,
      cancelUrl: j['cancelUrl'] as String?,
      attempt: attempt is Map<String, dynamic> ? CheckoutAttempt.fromJson(attempt) : null,
      expiresAt: j['expiresAt'] is String ? DateTime.tryParse(j['expiresAt'] as String) : null,
      canSaveCard: j['canSaveCard'] as bool? ?? false,
      savedCards: (j['savedCards'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(SavedCard.fromJson)
              .where((c) => c.token.isNotEmpty)
              .toList(growable: false) ??
          const [],
      savedCardSecurityCode: SavedCardSecurityCode.parse(j['savedCardSecurityCode']),
      locale: j['locale'] as String?,
    );
  }
}

/// What the SDK saw. The app shows it; the app's backend does not trust it.
class CheckoutResult {
  const CheckoutResult({required this.intentId, required this.state, this.attempt});

  final String intentId;

  /// The intent's state as last read: settled or authorized on success,
  /// open after a decline (the payer may try again), expired or cancelled.
  final String state;
  final CheckoutAttempt? attempt;

  bool get isSuccess => state == 'settled' || state == 'authorized';
  bool get isDeclined => attempt?.state == 'declined' || attempt?.state == 'failed';

  /// Plain-language reason safe to show, when the payment did not go through.
  String? get failureReason => attempt?.failureReason;
}

/// A refusal from the checkout edge or the gateway, or a transport failure.
class PesaCheckoutException implements Exception {
  const PesaCheckoutException(this.code, this.message, {this.status, this.field, this.detail});

  /// The gateway's error code (invalid_request, not_found, card_state,
  /// intent_closed, rate_limited…), or transport / pin_mismatch / timeout.
  /// Stable across languages: switch on it.
  final String code;

  /// Safe to show the payer, in the SDK's language (see
  /// `PesaCheckoutStrings`).
  final String message;
  final int? status;
  final String? field;

  /// For logs, not the payer: the gateway's English sentence or the
  /// transport error. Null when there is none.
  final String? detail;

  @override
  String toString() =>
      'PesaCheckoutException($code${status == null ? '' : ', $status'}): $message${detail == null ? '' : ' ($detail)'}';
}
