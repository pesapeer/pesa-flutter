/// Pesa card checkout for Flutter.
///
/// The app's backend creates an intent on the Pesa gateway and hands the
/// app the intent id and client secret. This SDK renders native card fields,
/// posts the card straight to `checkout.pesa.co` over pinned TLS, runs 3-D
/// Secure in the system browser, and reports the outcome it saw. The app's
/// backend trusts only the gateway's events or `GET /v1/intents/{ref}`,
/// never the result this SDK returns.
library;

export 'src/card.dart' show CardBrand, CardDetails, CardExpiry, CardValidation;
export 'src/client.dart' show PesaCheckout;
export 'src/models.dart'
    show
        CheckoutAttempt,
        CheckoutResult,
        CheckoutSession,
        CheckoutMerchant,
        PesaCheckoutException,
        SavedCard,
        SavedCardSecurityCode,
        WalletKind;
export 'src/pinning.dart' show SpkiPin;
export 'src/secure_screen.dart' show PesaSecureScreen;
export 'src/widgets/card_form.dart'
    show PesaCardField, PesaCardForm, PesaCardFormController, PesaCardTheme;
export 'src/widgets/pay_button.dart' show PesaPayButton;
export 'src/widgets/save_card_switch.dart' show PesaSaveCardSwitch;
