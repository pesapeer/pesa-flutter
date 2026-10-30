## 0.3.0

- Language: the SDK shows its text in `en`, `fr`, `fr-CA` and `zh-Hans`.
  It takes the `locale` the host passes, then the session's `locale`,
  then the app's and the device's locale, then English. Close tags are
  mapped (`fr-BE` to `fr`, `zh` and `zh-Hant` to `zh-Hans`).
- `PesaCheckoutStrings`: every user-visible string, with `of(context)`,
  `resolve(tag)`, `errorMessage(code)` and `money(amount, currency)`.
  `PesaCheckoutLocalizations.delegate` for `localizationsDelegates`
  (optional).
- `locale` on `PesaCardFormController`, `PesaCardForm`, `PesaPayButton`,
  `PesaSaveCardSwitch` and `PesaCheckout`.
- `CheckoutSession.locale`.
- `PesaPayButton` takes `amount` and `currency` and writes "Pay £25.00"
  in the payer's language. `label` is now optional and still wins.
- `PesaSaveCardSwitch.label` is now optional.
- `CardValidation` methods take `strings:`. English is the default.
- `PesaCheckoutException.message` is the SDK's own text for the code, in
  the payer's language. `code` is unchanged. The gateway's sentence (or
  the transport error) moves to the new `detail` field, and is the
  message only for a code the SDK does not know.

- The saved-card picker is one list in a single rounded box, with
  hairlines between rows. Each saved card is one row: brand mark on a
  white chip, `•••• last4`, the expiry, and a radio. The selected row
  fills its radio; no row gets a box of its own.
- The security code for a saved card sits on the selected card's row,
  when the session says `required` or `optional`.
- `savedCardSecurityCode` defaults to `never` when the session has no
  value or one the SDK does not know (was `optional`).
- Expired saved cards stay listed, greyed, with "Expired", and cannot be
  picked.
- "Use another card" is the list's last row. It opens the card fields
  under it, in the same box.
- `PesaCardForm` shows "Save this card for next time" as the last line of
  the card fields. Hosts that put `PesaSaveCardSwitch` under the form
  should remove it, or pass `showSaveCardSwitch: false`.
- `PesaCardTheme.listRadius` and `PesaCardTheme.saveCardSwitch` (draw the
  switch with the app's own).
- `CardBrand.fromCode` reads brand codes in any case and spelling (`VISA`,
  `MasterCard`, `MC`, `american_express`, `UnionPay`). Saved cards whose
  gateway brand was not exactly lowercase showed a generic card outline.

## 0.2.0

- Card on file. `CheckoutSession` has `canSaveCard`, `savedCards`
  (`SavedCard`: token, brand, last four, expiry, holder) and
  `savedCardSecurityCode` (`required`, `optional` or `never`).
- `PesaCheckout.payWithSavedCard(intentId, clientSecret, token,
  securityCode:, email:)` pays with a saved card. The outcome and 3-D
  Secure are the same as for `payWithCard`.
- `payWithCard(saveCard: true)` asks the checkout to keep the card once
  the charge succeeds.
- `PesaCardFormController.useSession(session)` makes `PesaCardForm` list
  the saved cards first, with the first card that has not expired
  selected, and "Use another card" after them. A selected card shows a
  security code field unless the session says `never`. Read
  `savedCard`, `savedCardCvv` and `saveCard` from the controller.
  `details()` is null while a saved card is selected.
- `PesaSaveCardSwitch`: "Save this card for next time", shown while the
  session offers it and the payer types a new card.
- `SavedCard.toString()` leaves the token out.
- New field style: filled fields with the label as a placeholder, an icon
  per field, a ring on the focused field, and a reserved error line under
  each field so nothing below moves.
- The number field shows the brand from its first digit, and a card
  outline until then.
- A field is checked when it is complete or when the cardholder leaves it
  with something typed. Focus moves on once a field is valid, unless the
  next one is already filled. Clearer error messages.
- The expiry adds the slash after the month. The security code is limited
  to the brand's length.
- The fields never offer to save the card to autofill.
- Haptics: a tick when the number is valid, a light tap when an error
  appears.
- iOS: `PesaSecureScreen` no longer re-parents the window under a secure
  text field. That trick clipped and scaled the screen on recent iOS and
  left it black after the app was backgrounded. The app-switcher cover
  stays; screenshots are no longer blocked on iOS.
- `openBrowser` is documented as the place to run 3-D Secure in an auth
  session; `challenge_cancelled` names the customer closing it.
- `PesaCardTheme`: `fillColor`, `focusFillColor`, `borderColor`,
  `hintColor`, `errorColor`, `fieldIcon`. `borderRadius` defaults to 12,
  `fieldSpacing` (the Expiry to CVV gap) to 10. `PesaCardField` names the
  fields for `fieldIcon`.
- `PesaPayButton` is a 54 pt pill.

## 0.1.0

- First release: native card fields, direct post to checkout.pesa.co,
  3-D Secure in the system browser, SPKI pinning, secure screen.
