## Unreleased

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
- `PesaCardTheme`: `fillColor`, `focusFillColor`, `borderColor`,
  `hintColor`, `errorColor`, `fieldIcon`. `borderRadius` defaults to 12,
  `fieldSpacing` (the Expiry to CVV gap) to 10. `PesaCardField` names the
  fields for `fieldIcon`.
- `PesaPayButton` is a 54 pt pill.

## 0.1.0

- First release: native card fields, direct post to checkout.pesa.co,
  3-D Secure in the system browser, SPKI pinning, secure screen.
