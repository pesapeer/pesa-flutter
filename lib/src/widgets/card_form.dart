import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../card.dart';
import 'brand_mark.dart';

/// The fields of [PesaCardForm].
enum PesaCardField { number, expiry, cvv, holder, email }

/// How the fields look: filled, with the label as a placeholder, a ring on
/// the focused field and an error line under each field.
class PesaCardTheme {
  const PesaCardTheme({
    this.primaryColor,
    this.borderRadius = 12,
    this.fieldSpacing = 10,
    this.textStyle,
    this.fillColor = const Color(0xFFF2F2F6),
    this.focusFillColor = const Color(0xFFFFFFFF),
    this.borderColor,
    this.hintColor = const Color(0xFF9C9BA6),
    this.errorColor = const Color(0xFFD92D20),
    this.fieldIcon,
  });

  /// The focus ring and the pay button. The theme's onSurface when null.
  final Color? primaryColor;
  final double borderRadius;

  /// The gap between Expiry and CVV. Rows are spaced by the error line.
  final double fieldSpacing;
  final TextStyle? textStyle;
  final Color fillColor;
  final Color focusFillColor;

  /// The border of a field that is neither focused nor in error. None when
  /// null.
  final Color? borderColor;

  /// Placeholders, icons of empty fields and the empty-number card outline.
  final Color hintColor;
  final Color errorColor;

  /// The icon at the start of each field; null for none. Material icons
  /// when this is not set.
  final Widget? Function(PesaCardField field)? fieldIcon;
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
  final _focus = {for (final field in PesaCardField.values) field: FocusNode()};
  final _errors = <PesaCardField, String>{};
  PesaCardField? _focused;
  bool _numberValid = false;

  PesaCardFormController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c._needsEmail = widget.needsEmail;
    _c.addListener(_rebuild);
    for (final node in _focus.values) {
      node.addListener(_onFocusChange);
    }
  }

  @override
  void didUpdateWidget(PesaCardForm old) {
    super.didUpdateWidget(old);
    _c._needsEmail = widget.needsEmail;
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      _c.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_rebuild);
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  TextEditingController _input(PesaCardField field) => switch (field) {
        PesaCardField.number => _c.number,
        PesaCardField.expiry => _c.expiry,
        PesaCardField.cvv => _c.cvv,
        PesaCardField.holder => _c.holder,
        PesaCardField.email => _c.email,
      };

  String? _check(PesaCardField field) => switch (field) {
        PesaCardField.number => CardValidation.number(_c.number.text),
        PesaCardField.expiry => CardValidation.expiry(_c.expiry.text),
        PesaCardField.cvv => CardValidation.securityCode(_c.cvv.text, _c.brand),
        PesaCardField.holder => CardValidation.holderName(_c.holder.text),
        PesaCardField.email => CardValidation.email(_c.email.text),
      };

  void _show(PesaCardField field, String? message) {
    if (message == _errors[field]) return;
    if (message != null && _errors[field] == null) HapticFeedback.lightImpact();
    setState(() {
      if (message == null) {
        _errors.remove(field);
      } else {
        _errors[field] = message;
      }
    });
  }

  /// A field is checked when it is left with something typed; leaving an
  /// empty field clears its error.
  void _onFocusChange() {
    final now = PesaCardField.values.where((f) => _focus[f]!.hasFocus).firstOrNull;
    if (now == _focused) return;
    final left = _focused;
    setState(() => _focused = now);
    if (left != null) _show(left, _input(left).text.isEmpty ? null : _check(left));
  }

  /// Moves on to [next] unless the cardholder already filled it.
  void _advance(PesaCardField next) {
    if (_input(next).text.isEmpty) _focus[next]!.requestFocus();
  }

  void _onNumberChanged() {
    final complete = _c._digits.length >= _c.brand.maxLength;
    final message = complete ? CardValidation.number(_c.number.text) : null;
    _show(PesaCardField.number, message);
    final valid = CardValidation.number(_c.number.text) == null;
    if (valid && !_numberValid) HapticFeedback.selectionClick();
    _numberValid = valid;
    if (complete && valid) _advance(PesaCardField.expiry);
  }

  void _onExpiryChanged(String text) {
    final complete = text.replaceAll(RegExp(r'\D'), '').length == 4;
    final message = complete ? CardValidation.expiry(text) : null;
    _show(PesaCardField.expiry, message);
    if (complete && message == null) _advance(PesaCardField.cvv);
  }

  void _onCvvChanged(String text) {
    _show(PesaCardField.cvv, null);
    if (text.length == _c.brand.cvvLength) _advance(PesaCardField.holder);
  }

  void _leave(PesaCardField field, PesaCardField? next) {
    if (next != null) {
      _focus[next]!.requestFocus();
    } else {
      _focus[field]!.unfocus();
    }
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Duration _motion(int milliseconds) => _reduceMotion ? Duration.zero : Duration(milliseconds: milliseconds);

  static Widget _defaultIcon(PesaCardField field) => Icon(switch (field) {
        PesaCardField.number => Icons.credit_card_outlined,
        PesaCardField.expiry => Icons.calendar_today_outlined,
        PesaCardField.cvv => Icons.lock_outline,
        PesaCardField.holder => Icons.person_outline,
        PesaCardField.email => Icons.mail_outline,
      });

  /// The brand once its first digit is typed. The mark goes back to the
  /// card outline when a later digit rules the brand out.
  static CardBrand _shownBrand(String digits) {
    final brand = CardBrand.detect(digits);
    if (brand != CardBrand.unknown) return brand;
    if (digits == '5') return CardBrand.mastercard;
    if (digits.length < 4 && RegExp(r'^2[2-7]').hasMatch(digits)) return CardBrand.mastercard;
    return CardBrand.unknown;
  }

  Widget _brandSlot() {
    final brand = _shownBrand(_c._digits);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 38, minHeight: 24),
      child: AnimatedSwitcher(
        duration: _motion(180),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerRight,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.75, end: 1.0).animate(animation), child: child),
        ),
        child: brand == CardBrand.unknown
            ? CustomPaint(
                key: const ValueKey(CardBrand.unknown),
                size: const Size(30, 20),
                painter: _CardOutlinePainter(widget.theme.hintColor),
              )
            : CardBrandMark(key: ValueKey(brand), brand: brand, height: 20),
      ),
    );
  }

  /// One filled field with its icon, an optional [trailing] widget, and a
  /// reserved line for its error so the fields below never move.
  Widget _field(PesaCardField field, TextField input, {Widget? trailing}) {
    final t = widget.theme;
    final ink = t.primaryColor ?? Theme.of(context).colorScheme.onSurface;
    final error = _errors[field];
    final focused = _focused == field;
    final radius = BorderRadius.circular(t.borderRadius);
    final icon = (t.fieldIcon ?? _defaultIcon)(field);
    final iconColor = switch (error) {
      String() => t.errorColor,
      null when focused || _input(field).text.isNotEmpty => ink,
      null => t.hintColor,
    };
    final ring = switch (error) {
      String() => BorderSide(color: t.errorColor, width: 1.5),
      null when focused => BorderSide(color: ink, width: 1.5),
      null => t.borderColor == null ? BorderSide.none : BorderSide(color: t.borderColor!),
    };
    final fill = switch (error) {
      String() => Color.alphaBlend(t.errorColor.withValues(alpha: 0.06), t.focusFillColor),
      null when focused => t.focusFillColor,
      null => t.fillColor,
    };
    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _focus[field]!.requestFocus : null,
            child: AnimatedContainer(
              duration: _motion(150),
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: fill, borderRadius: radius),
              foregroundDecoration: BoxDecoration(borderRadius: radius, border: Border.fromBorderSide(ring)),
              child: Row(
                children: [
                  if (icon != null) ...[
                    IconTheme.merge(data: IconThemeData(size: 20, color: iconColor), child: icon),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: input),
                  if (trailing != null) ...[const SizedBox(width: 10), trailing],
                ],
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Semantics(
                liveRegion: error != null,
                child: Text(
                  error ?? '',
                  style: TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500, color: t.errorColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The field draws its own box; the TextField inside must draw nothing,
  /// whatever the host app's InputDecorationTheme says.
  InputDecoration _placeholder(String text) => InputDecoration(
        hintText: text,
        hintStyle: TextStyle(color: widget.theme.hintColor, fontWeight: FontWeight.w400),
        isDense: true,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        counterText: '',
      );

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
    final brand = _c.brand;
    final style = const TextStyle(fontSize: 16, fontWeight: FontWeight.w500).merge(widget.theme.textStyle);
    return AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            PesaCardField.number,
            TextField(
              controller: _c.number,
              focusNode: _focus[PesaCardField.number],
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              style: style,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.creditCardNumber],
              enableSuggestions: false,
              autocorrect: false,
              enableInteractiveSelection: false,
              contextMenuBuilder: _noCopyMenu,
              inputFormatters: [_CardNumberFormatter()],
              decoration: _placeholder('Card number'),
              onChanged: (_) => _onNumberChanged(),
              onEditingComplete: () => _leave(PesaCardField.number, PesaCardField.expiry),
            ),
            trailing: _brandSlot(),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  PesaCardField.expiry,
                  TextField(
                    controller: _c.expiry,
                    focusNode: _focus[PesaCardField.expiry],
                    enabled: widget.enabled,
                    style: style,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.creditCardExpirationDate],
                    enableSuggestions: false,
                    autocorrect: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [_ExpiryFormatter()],
                    decoration: _placeholder('MM/YY'),
                    onChanged: _onExpiryChanged,
                    onEditingComplete: () => _leave(PesaCardField.expiry, PesaCardField.cvv),
                  ),
                ),
              ),
              SizedBox(width: widget.theme.fieldSpacing),
              Expanded(
                child: _field(
                  PesaCardField.cvv,
                  TextField(
                    controller: _c.cvv,
                    focusNode: _focus[PesaCardField.cvv],
                    enabled: widget.enabled,
                    style: style,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    obscureText: true,
                    autofillHints: const [AutofillHints.creditCardSecurityCode],
                    enableSuggestions: false,
                    autocorrect: false,
                    enableInteractiveSelection: false,
                    contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(brand == CardBrand.unknown ? 4 : brand.cvvLength),
                    ],
                    decoration: _placeholder(brand == CardBrand.amex ? 'CID' : 'CVV'),
                    onChanged: _onCvvChanged,
                    onEditingComplete: () => _leave(PesaCardField.cvv, PesaCardField.holder),
                  ),
                ),
              ),
            ],
          ),
          _field(
            PesaCardField.holder,
            TextField(
              controller: _c.holder,
              focusNode: _focus[PesaCardField.holder],
              enabled: widget.enabled,
              style: style,
              textCapitalization: TextCapitalization.words,
              textInputAction: widget.needsEmail ? TextInputAction.next : TextInputAction.done,
              autofillHints: const [AutofillHints.creditCardName],
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [LengthLimitingTextInputFormatter(26)],
              decoration: _placeholder('Name on card'),
              onChanged: (_) => _show(PesaCardField.holder, null),
              onEditingComplete: () =>
                  _leave(PesaCardField.holder, widget.needsEmail ? PesaCardField.email : null),
            ),
          ),
          if (widget.needsEmail)
            _field(
              PesaCardField.email,
              TextField(
                controller: _c.email,
                focusNode: _focus[PesaCardField.email],
                enabled: widget.enabled,
                style: style,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                decoration: _placeholder('Email for your receipt'),
                onChanged: (_) => _show(PesaCardField.email, null),
                onEditingComplete: () => _leave(PesaCardField.email, null),
              ),
            ),
        ],
      ),
    );
  }
}

/// The neutral card shown in the number field until a brand is known.
class _CardOutlinePainter extends CustomPainter {
  const _CardOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 30;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromLTRBR(1 * s, 1.5 * s, 29 * s, 18.5 * s, Radius.circular(3 * s)), line);
    canvas.drawLine(Offset(1 * s, 6.5 * s), Offset(29 * s, 6.5 * s), line);
    canvas.drawLine(Offset(5 * s, 13.5 * s), Offset(11 * s, 13.5 * s), line);
  }

  @override
  bool shouldRepaint(_CardOutlinePainter oldDelegate) => oldDelegate.color != color;
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

/// MM/YY: a lone 2 to 9 becomes 02 to 09, and the slash follows the month
/// unless the cardholder is deleting.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    if (digits.length == 1 && int.parse(digits) > 1) digits = '0$digits';
    final deleting = newValue.text.length < oldValue.text.length;
    final text = switch (digits.length) {
      > 2 => '${digits.substring(0, 2)}/${digits.substring(2)}',
      2 when !deleting => '$digits/',
      _ => digits,
    };
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
