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
