---
name: pesa-checkout-flutter
description: Add a native Pesa card payment screen to a Flutter app with the pesa_checkout package. Use when a Flutter app must take a card payment on a Pesa intent without a web view.
---

# Pesa Checkout in Flutter

## When to use this skill

The merchant has a Pesa account and an API key on the server. The Flutter
app must take a card payment with native fields.

## Steps

1. Server: create an intent with `POST /v1/intents`. Set `returnUrl` to
   an https app link of the app. Send `id` and `clientSecret` to the app.
   Do not log `clientSecret`.

2. App: install.

   ```
   flutter pub add pesa_checkout
   ```

   Android 11+: add to `AndroidManifest.xml`:

   ```xml
   <queries>
     <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
   </queries>
   ```

3. App: create one client.

   ```dart
   final checkout = PesaCheckout(pins: const ['<pin 1>', '<pin 2>']);
   ```

4. App: build the payment screen.

   ```dart
   final form = PesaCardFormController();

   PesaSecureScreen(
     child: Column(children: [
       PesaCardForm(controller: form, needsEmail: session.needsEmail),
       PesaPayButton(controller: form, label: 'Pay', busy: busy, onPressed: pay),
     ]),
   )

   Future<void> pay() async {
     final card = form.details();
     if (card == null) return;
     try {
       final r = await checkout.payWithCard(intentId, clientSecret, card, email: form.emailText);
       if (r.isSuccess) { /* show paid */ }
       else if (r.isDeclined) { /* show r.failureReason; the customer can try again */ }
       else { /* intent closed: expired or cancelled */ }
     } on PesaCheckoutException catch (e) {
       switch (e.code) {
         case 'pin_mismatch': /* stop; report to the merchant */ break;
         case 'rate_limited': /* wait, then let the customer retry */ break;
         default: /* show e.message */ break;
       }
     } finally {
       form.clear();
     }
   }
   ```

5. App: declare and verify the app link (`assetlinks.json` on Android,
   `apple-app-site-association` on iOS).

6. Server: handle the `intent.state_changed` webhook. Fulfil the order on
   `state: settled`. Fulfil on `authorized` only when the merchant
   captures by hand.

## Checks before you finish

- [ ] The API key is on the server only.
- [ ] `clientSecret` is not logged and not stored.
- [ ] `pins` has two values in release builds.
- [ ] `PesaSecureScreen` wraps the card screen.
- [ ] `form.clear()` runs in `finally`.
- [ ] The app link is declared and verified.
- [ ] Order fulfilment uses the webhook or the intent read.

## Reference

Full API and error codes: `README.md` in https://github.com/pesapeer/pesa-flutter.
