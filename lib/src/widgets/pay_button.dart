import 'package:flutter/material.dart';

import 'card_form.dart';

/// A full-width pay button that is enabled only while the form is complete
/// and shows a spinner while [busy].
class PesaPayButton extends StatelessWidget {
  const PesaPayButton({
    super.key,
    required this.controller,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.theme = const PesaCardTheme(),
  });

  final PesaCardFormController controller;

  /// For instance "Pay £25.00".
  final String label;
  final VoidCallback onPressed;
  final bool busy;
  final PesaCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final enabled = controller.isComplete && !busy;
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.primaryColor,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.borderRadius)),
          ),
          onPressed: enabled ? onPressed : null,
          child: busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label),
        );
      },
    );
  }
}
