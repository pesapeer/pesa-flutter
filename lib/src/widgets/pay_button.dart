import 'package:flutter/material.dart';

import 'card_form.dart';

/// A full-width pill pay button that is enabled only while the form is
/// complete and shows a spinner while [busy].
///
/// The text is [label] when set. Otherwise it is "Pay [amount]" with the
/// amount written for the language (£25.00, 25,00 £), or "Pay" without
/// [amount] and [currency]. The language follows [locale], then the
/// controller's (see [PesaCardFormController]).
class PesaPayButton extends StatelessWidget {
  const PesaPayButton({
    super.key,
    required this.controller,
    required this.onPressed,
    this.label,
    this.amount,
    this.currency,
    this.busy = false,
    this.theme = const PesaCardTheme(),
    this.locale,
  });

  final PesaCardFormController controller;

  /// The host's own text, used as is.
  final String? label;

  /// A decimal string such as the session's `amount` ("25.00").
  final String? amount;

  /// An ISO 4217 code such as the session's `currency` ("GBP").
  final String? currency;
  final Locale? locale;
  final VoidCallback onPressed;
  final bool busy;
  final PesaCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final enabled = controller.isComplete && !busy;
        final s = controller.strings(context, locale: locale);
        final text = label ??
            (amount != null && currency != null ? s.payAmount(amount!, currency!) : s.pay);
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.primaryColor ?? Theme.of(context).colorScheme.onSurface,
            disabledBackgroundColor: const Color(0xFFE6E6EB),
            disabledForegroundColor: const Color(0xFFA5A4AF),
            minimumSize: const Size.fromHeight(54),
            shape: const StadiumBorder(),
          ),
          onPressed: enabled ? onPressed : null,
          child: busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        );
      },
    );
  }
}
