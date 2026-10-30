# Pesa Checkout for Flutter (pesa_checkout)

[![CI](https://github.com/pesapeer/pesa-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/pesapeer/pesa-flutter/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/pesa_checkout.svg)](https://pub.dev/packages/pesa_checkout)

Card payments on a Pesa intent for Flutter apps.

- Native card fields. No web views.
- The card number goes from the field to `checkout.pesa.co` over pinned
  TLS. Your app code never holds a PAN.
- 3-D Secure runs in the system browser.

Other platforms: [pesa-ios](https://github.com/pesapeer/pesa-ios),
[pesa-kotlin](https://github.com/pesapeer/pesa-kotlin),
[pesa-js](https://github.com/pesapeer/pesa-js).

## How a payment works

1. Your server creates an intent: `POST /v1/intents` on the Pesa API.
   Set `returnUrl` to an https app link of your app.
2. Your server gives the app `id` and `clientSecret`. Never the API key.
   Keep `clientSecret` out of logs.
3. The app shows `PesaCardForm` inside `PesaSecureScreen`. Then it calls
   `PesaCheckout.payWithCard`.
4. The SDK posts the card, polls the result, and opens the 3-D Secure
   challenge in the browser when the issuer asks. It returns a
   `CheckoutResult` when the attempt is no longer pending.

   Pass `openBrowser` to `PesaCheckout` and open the challenge in an auth
   session (`flutter_web_auth_2`, callback scheme = your app's scheme).
   When the challenge is done the checkout sends the browser to your
   `returnUrl`, whose page redirects to your app's custom scheme; an auth
   session catches that and closes itself. The default, a plain in-app
   browser, does not: iOS will not open your app from a script redirect,
   and the customer is left on a web page. Throw
   `PesaCheckoutException('challenge_cancelled', …)` from `openBrowser`
   when the customer closes the session, and return `false` when it could
   not be opened at all.
5. **Your server trusts only the gateway.** It fulfils the order on
   `intent.state_changed` with `state: settled` (or `authorized` for
   manual capture), or on `GET /v1/intents/{reference}`. The result the
   SDK returns is for the screen only.

## Install

```
flutter pub add pesa_checkout
```

Requirements: Android minSdk 24. iOS 15.0.

The challenge opens through `url_launcher`. On Android 11 and later, add
this to `AndroidManifest.xml`:

```xml
<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
</queries>
```

## Example

```dart
final checkout = PesaCheckout(
  pins: const ['<pin 1>', '<pin 2>'],   // SPKI pins of checkout.pesa.co. Required in release builds.
);

final form = PesaCardFormController();

// Payment screen:
PesaSecureScreen(
  child: Column(children: [
    PesaCardForm(controller: form, needsEmail: session.needsEmail),
    PesaPayButton(controller: form, label: 'Pay £25.00', busy: busy, onPressed: pay),
  ]),
)

Future<void> pay() async {
  final card = form.details();
  if (card == null) return;
  try {
    final r = await checkout.payWithCard(intentId, clientSecret, card, email: form.emailText);
    if (r.isSuccess) {
      // Show "paid". Your server confirms on the event.
    } else if (r.isDeclined) {
      // Show r.failureReason. The intent is still open. The customer can try another card.
    }
  } on PesaCheckoutException catch (e) {
    // e.code: see "Error codes" below
  } finally {
    form.clear();
  }
}
```

`checkout.session(intentId, clientSecret)` returns the amount, currency,
merchant name, `needsEmail`, and the latest attempt. Use it to draw the
screen before the form.

## Saved cards

The checkout can keep a card for the next payment. The acquirer keeps
the card. The app gets a token, the brand, the last four digits and the
expiry. It never gets the number.

Saved cards need a customer. Your server sets `customerReference` on
the intent. Without it, the session has no saved cards and
`canSaveCard` is false.

1. Read the session. Give it to the form controller:

   ```dart
   final session = await checkout.session(intentId, clientSecret);
   form.useSession(session);
   ```

2. `PesaCardForm` shows the saved cards first. It selects the first card
   that has not expired. "Use another card" shows the card fields.
3. Put `PesaSaveCardSwitch(controller: form)` under the form. It shows
   only when `session.canSaveCard` is true and the payer types a new
   card. Or bind your own switch to `form.saveCard`.
4. On pay, check `form.savedCard`:

   ```dart
   final saved = form.savedCard;
   final r = saved != null
       ? await checkout.payWithSavedCard(intentId, clientSecret, saved.token,
           securityCode: form.savedCardCvv, email: form.emailText)
       : await checkout.payWithCard(intentId, clientSecret, form.details()!,
           email: form.emailText, saveCard: form.saveCard);
   ```

   Call `form.clear()` in `finally`, as for a typed card. The selection
   stays.

`session.savedCardSecurityCode` controls the security code field:

| Value | Field |
|---|---|
| `required` | Shown. The pay button stays off until the code is valid. |
| `optional` | Shown. The code is sent when the payer types one. |
| `never` | Not shown. No code is sent. |

The checkout keeps the card only when the payer turns on the switch and
the charge succeeds. A decline keeps nothing.

Rules:

- The token is opaque. Do not log it. `SavedCard.toString()` leaves it
  out.
- The SDK reads the security code once and does not keep it.
- The checkout refuses a token that is not on file for the intent's
  customer. The `PesaCheckoutException` has status 400 and `field`
  `savedCard.token`. Show the card fields.

## Field style

The fields are filled, 54 pt high, with the label as a placeholder and an
icon at the start. The focused field turns white with a ring. A field in
error turns red and shows its message on a line kept free under it, so the
fields below never move. The number field shows the brand mark from the
first digit.

Theme them with `PesaCardTheme`:

```dart
final cardTheme = PesaCardTheme(
  primaryColor: Colors.black,          // focus ring and pay button
  fillColor: const Color(0xFFF2F2F6),
  focusFillColor: Colors.white,
  borderColor: null,                   // no border at rest
  hintColor: const Color(0xFF9C9BA6),
  errorColor: const Color(0xFFD92D20),
  fieldIcon: (field) => switch (field) {
    PesaCardField.number => const Icon(Icons.credit_card_outlined),
    _ => null,                          // null: no icon
  },
);

PesaCardForm(controller: form, theme: cardTheme)
PesaPayButton(controller: form, label: 'Pay £25.00', onPressed: pay, theme: cardTheme)
```

| Field | Default |
|---|---|
| `primaryColor` | The theme's `onSurface` |
| `borderRadius` | 12 |
| `fieldSpacing` | 10, the gap between Expiry and CVV |
| `fillColor`, `focusFillColor` | `#F2F2F6`, white |
| `borderColor` | None |
| `hintColor`, `errorColor` | `#9C9BA6`, `#D92D20` |
| `fieldIcon` | Material outlined icons. Icons take their colour from the field state. |

## Error codes

`PesaCheckoutException.code` is one of:

| Code | Meaning |
|---|---|
| `invalid_request` | The checkout service refused the request. `field` names the bad field when known. |
| `not_found` | Unknown intent or wrong client secret. |
| `card_state` | The card attempt is in a state that does not allow this call. |
| `intent_closed` | The intent is settled, cancelled or expired. |
| `rate_limited` | Too many requests. Wait and retry. |
| `transport` | Network error. |
| `pin_mismatch` | The server key did not match a pin. The SDK sent no request. |
| `timeout` | No final state before the poll limit. |
| `challenge_unavailable` | `openBrowser` returned `false`: the 3-D Secure page could not be opened. |
| `challenge_cancelled` | Your `openBrowser` threw it: the customer closed the 3-D Secure session. |

## Certificate pins

A pin is the base64 SHA-256 of the SubjectPublicKeyInfo of the
`checkout.pesa.co` certificate. Android's network security config uses
the same format. Get the current pin:

```
openssl s_client -connect checkout.pesa.co:443 -servername checkout.pesa.co </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64
```

Rules:

- Ship two pins: current and backup. Then a certificate rotation never
  locks the app out. Pesa publishes the pins with each release.
- An empty list turns pinning off. Use that only for development against
  a local checkout service.
- The SDK checks the pin on the TLS socket, after normal chain
  validation, before it sends any request byte.

## How the SDK keeps card data safe

- `PesaSecureScreen` hides the card screen in the app switcher on both
  platforms and, on Android, in screenshots and recordings (`FLAG_SECURE`).
  iOS has no supported way to block screenshots, so it does not try.
- The number field has no copy or cut menu and no selection handles. The
  security code is obscured and has no context menu. Suggestions and
  autocorrect are off.
- The fields sit in an autofill group that never asks the platform to
  save the card.
- The SDK logs nothing. `PesaCardFormController.clear()` overwrites and
  empties the fields. Call it after every attempt.
- The SDK posts the card once, over pinned TLS, to the checkout service
  only. It never caches the card. A saved card goes as its token, with
  the security code when one was typed.

Apple Pay and Google Pay (`payWithWallet`) arrive in the next release.

## For AI agents

Read [AGENTS.md](AGENTS.md). It has the integration steps in order and the
rules an agent must follow. A skill is in `skills/pesa-checkout-flutter/`.

## Security

Read [SECURITY.md](SECURITY.md). Report vulnerabilities to
security@pesa.co. Do not open a public issue.

## Releasing

1. Set the version in `pubspec.yaml`. Move the Unreleased notes in
   `CHANGELOG.md`.
2. Tag with an SSH key listed in `.github/allowed_signers`:
   `git tag -s vX.Y.Z -m "vX.Y.Z"`. Push the tag.
3. `release.yml` verifies the tag signature, runs the tests, publishes
   `pesa_checkout` to pub.dev through automated publishing (OIDC), and
   creates a GitHub release.

Repository setup: pub.dev automated publishing for `pesa_checkout` from
`pesapeer/pesa-flutter`, workflow `release.yml`, tag pattern
`v{{version}}`. No token secret. `.github/allowed_signers`.

## Develop

```
flutter analyze
make test          # generates the TLS test fixtures on first run, then runs flutter test
cd example && flutter run
```

`make test` needs `openssl`. The fixtures are a self-signed `localhost`
key and certificate in `test/fixtures/`. They are not committed.

The example app takes a checkout URL, an intent id and a client secret.
It runs the full flow. Use the Pesa sandbox test cards:
`4111 1111 1111 1111` (no 3-D Secure) and `4012 8888 8888 1881`
(3-D Secure), expiry 12/28.

## License

MIT. See [LICENSE](LICENSE).
