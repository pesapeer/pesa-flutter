import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../card.dart';

/// How the fields look. Defaults follow the app's Material theme.
class PesaCardTheme {
  const PesaCardTheme({this.primaryColor, this.borderRadius = 10, this.fieldSpacing = 12, this.textStyle});

  final Color? primaryColor;
  final double borderRadius;
  final double fieldSpacing;
  final TextStyle? textStyle;
}

/// Holds what the cardholder typed and reports whether it is complete.
///
/// Everything stays in the controllers until [clear] runs. Call it after
/// the payment was sent, whatever the outcome.
class PesaCardFormController extends ChangeNotifier {
  PesaCardFormController() {
    for (final c in [number, expiry, cvv, holder, email]) {
      c.addListener(notifyListeners);
    }
  }

  final number = TextEditingController();
  final expiry = TextEditingController();
  final cvv = TextEditingController();
  final holder = TextEditingController();
  final email = TextEditingController();

  bool _needsEmail = false;

  CardBrand get brand => CardBrand.detect(_digits);
  String get _digits => number.text.replaceAll(RegExp(r'\s'), '');

  /// Whether every field passes its check.
  bool get isComplete =>
      CardValidation.number(number.text) == null &&
      CardValidation.expiry(expiry.text) == null &&
      CardValidation.securityCode(cvv.text, brand) == null &&
      CardValidation.holderName(holder.text) == null &&
      (!_needsEmail || CardValidation.email(email.text) == null);

  /// The card, or null when [isComplete] is false.
  CardDetails? details() {
    if (!isComplete) return null;
    return CardDetails(
      number: _digits,
      expiry: CardExpiry.parse(expiry.text)!,
      securityCode: cvv.text,
      holderName: holder.text,
    );
  }

  String? get emailText => _needsEmail ? email.text.trim() : null;

  /// Empties every field. The number and code are overwritten before being
  /// cleared so the previous text is not left in the controller's value.
  void clear() {
    for (final c in [number, cvv]) {
      c.value = TextEditingValue(text: '0' * c.text.length);
    }
    for (final c in [number, expiry, cvv, holder, email]) {
      c.clear();
    }
  }

  @override
  void dispose() {
    clear();
    for (final c in [number, expiry, cvv, holder, email]) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Native card fields: number, expiry, security code, holder, and email when
/// the checkout needs one. Nothing here leaves the widget tree except
/// through [PesaCardFormController.details].
class PesaCardForm extends StatefulWidget {
  const PesaCardForm({
    super.key,
    required this.controller,
    this.needsEmail = false,
    this.theme = const PesaCardTheme(),
    this.enabled = true,
    this.autofocus = false,
  });

  final PesaCardFormController controller;
  final bool needsEmail;
  final PesaCardTheme theme;
  final bool enabled;
  final bool autofocus;

  @override
  State<PesaCardForm> createState() => _PesaCardFormState();
}

class _PesaCardFormState extends State<PesaCardForm> {
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _holderFocus = FocusNode();
  final _emailFocus = FocusNode();
  bool _touchedNumber = false, _touchedExpiry = false, _touchedCvv = false, _touchedHolder = false, _touchedEmail = false;

  @override
  void initState() {
    super.initState();
    widget.controller._needsEmail = widget.needsEmail;
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(PesaCardForm old) {
    super.didUpdateWidget(old);
    widget.controller._needsEmail = widget.needsEmail;
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    for (final f in [_expiryFocus, _cvvFocus, _holderFocus, _emailFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String label, {String? error, Widget? suffix, String? hint}) {
    final t = widget.theme;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(t.borderRadius));
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      suffixIcon: suffix,
      border: border,
      focusedBorder: t.primaryColor == null ? null : border.copyWith(borderSide: BorderSide(color: t.primaryColor!, width: 2)),
      isDense: true,
    );
  }

  /// A context menu without copy or cut: a card number must not travel to
  /// the clipboard, but pasting one in is a normal thing to do.
  Widget _noCopyMenu(BuildContext context, EditableTextState state) {
    final items = state.contextMenuButtonItems
        .where((b) => b.type != ContextMenuButtonType.copy && b.type != ContextMenuButtonType.cut)
        .toList();
    return AdaptiveTextSelectionToolbar.buttonItems(anchors: state.contextMenuAnchors, buttonItems: items);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final brand = c.brand;
    final gap = SizedBox(height: widget.theme.fieldSpacing);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: c.number,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          style: widget.theme.textStyle,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.creditCardNumber],
          enableSuggestions: false,
          autocorrect: false,
          enableInteractiveSelection: false,
          contextMenuBuilder: _noCopyMenu,
          inputFormatters: [_CardNumberFormatter()],
          decoration: _decoration(
            'Card number',
            error: _touchedNumber ? CardValidation.number(c.number.text) : null,
            suffix: brand == CardBrand.unknown
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 12, top: 14),
                    child: Text(brand.label, style: Theme.of(context).textTheme.labelMedium),
                  ),
          ),
          onChanged: (_) => _touchedNumber = _touchedNumber || c.number.text.replaceAll(' ', '').length >= brand.minLength,
          onEditingComplete: () {
            setState(() => _touchedNumber = true);
            _expiryFocus.requestFocus();
          },
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: c.expiry,
                focusNode: _expiryFocus,
                enabled: widget.enabled,
                style: widget.theme.textStyle,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.creditCardExpirationDate],
                enableSuggestions: false,
                autocorrect: false,
                enableInteractiveSelection: false,
                inputFormatters: [_ExpiryFormatter()],
                decoration: _decoration('Expiry', hint: 'MM/YY', error: _touchedExpiry ? CardValidation.expiry(c.expiry.text) : null),
                onChanged: (v) {
                  if (v.length == 5) {
                    setState(() => _touchedExpiry = true);
                    _cvvFocus.requestFocus();
                  }
                },
                onEditingComplete: () {
                  setState(() => _touchedExpiry = true);
                  _cvvFocus.requestFocus();
                },
              ),
            ),
            SizedBox(width: widget.theme.fieldSpacing),
            Expanded(
              child: TextField(
                controller: c.cvv,
                focusNode: _cvvFocus,
                enabled: widget.enabled,
                style: widget.theme.textStyle,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                obscureText: true,
                autofillHints: const [AutofillHints.creditCardSecurityCode],
                enableSuggestions: false,
                autocorrect: false,
                enableInteractiveSelection: false,
                contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: _decoration(brand == CardBrand.amex ? 'CID' : 'CVV', error: _touchedCvv ? CardValidation.securityCode(c.cvv.text, brand) : null),
                onChanged: (v) {
                  if (v.length == brand.cvvLength) {
                    setState(() => _touchedCvv = true);
                    _holderFocus.requestFocus();
                  }
                },
                onEditingComplete: () {
                  setState(() => _touchedCvv = true);
                  _holderFocus.requestFocus();
                },
              ),
            ),
          ],
        ),
        gap,
        TextField(
          controller: c.holder,
          focusNode: _holderFocus,
          enabled: widget.enabled,
          style: widget.theme.textStyle,
          textCapitalization: TextCapitalization.words,
          textInputAction: widget.needsEmail ? TextInputAction.next : TextInputAction.done,
          autofillHints: const [AutofillHints.creditCardName],
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [LengthLimitingTextInputFormatter(26)],
          decoration: _decoration('Name on card', error: _touchedHolder ? CardValidation.holderName(c.holder.text) : null),
          onEditingComplete: () {
            setState(() => _touchedHolder = true);
            if (widget.needsEmail) {
              _emailFocus.requestFocus();
            } else {
              FocusScope.of(context).unfocus();
            }
          },
        ),
        if (widget.needsEmail) ...[
          gap,
          TextField(
            controller: c.email,
            focusNode: _emailFocus,
            enabled: widget.enabled,
            style: widget.theme.textStyle,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
            decoration: _decoration('Email for your receipt', error: _touchedEmail ? CardValidation.email(c.email.text) : null),
            onEditingComplete: () {
              setState(() => _touchedEmail = true);
              FocusScope.of(context).unfocus();
            },
          ),
        ],
      ],
    );
  }
}

/// Digits only, grouped with spaces for the detected brand.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final brand = CardBrand.detect(digits);
    final kept = digits.length > brand.maxLength ? digits.substring(0, brand.maxLength) : digits;
    final text = CardValidation.format(kept, brand);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// MM/YY with the slash inserted as the user types.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    if (digits.length == 1 && int.parse(digits) > 1) digits = '0$digits';
    final text = digits.length <= 2 ? digits : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
