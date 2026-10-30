import 'package:flutter/material.dart';

import 'card_form.dart';

/// "Save this card for next time". Shown only while the session offers it
/// and the payer types a new card; it sets [PesaCardFormController.saveCard].
///
/// [PesaCardForm] already shows it as the last line of the card fields.
/// Use this widget on its own only with `showSaveCardSwitch: false` there.
class PesaSaveCardSwitch extends StatelessWidget {
  const PesaSaveCardSwitch({
    super.key,
    required this.controller,
    this.label,
    this.enabled = true,
    this.theme = const PesaCardTheme(),
    this.locale,
  });

  final PesaCardFormController controller;

  /// The host's own text; "Save this card for next time" in the
  /// controller's language when null.
  final String? label;
  final Locale? locale;
  final bool enabled;
  final PesaCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.canSaveCard || controller.savedCard != null) return const SizedBox.shrink();
        final style = const TextStyle(fontSize: 15, fontWeight: FontWeight.w500).merge(theme.textStyle);
        final ValueChanged<bool>? onChanged = enabled ? (value) => controller.saveCard = value : null;
        return MergeSemantics(
          child: Row(
            children: [
              Expanded(child: Text(label ?? controller.strings(context, locale: locale).saveCard, style: style)),
              theme.saveCardSwitch?.call(controller.saveCard, onChanged) ??
                  Switch.adaptive(
                    value: controller.saveCard,
                    activeTrackColor: theme.primaryColor ?? Theme.of(context).colorScheme.onSurface,
                    onChanged: onChanged,
                  ),
            ],
          ),
        );
      },
    );
  }
}
