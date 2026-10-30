import 'package:flutter/material.dart';

import 'card_form.dart';

/// "Save this card for next time". Shown only while the session offers it
/// and the payer types a new card; it sets [PesaCardFormController.saveCard].
class PesaSaveCardSwitch extends StatelessWidget {
  const PesaSaveCardSwitch({
    super.key,
    required this.controller,
    this.label = 'Save this card for next time',
    this.enabled = true,
    this.theme = const PesaCardTheme(),
  });

  final PesaCardFormController controller;
  final String label;
  final bool enabled;
  final PesaCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.canSaveCard || controller.savedCard != null) return const SizedBox.shrink();
        final style = const TextStyle(fontSize: 15, fontWeight: FontWeight.w500).merge(theme.textStyle);
        return MergeSemantics(
          child: Row(
            children: [
              Expanded(child: Text(label, style: style)),
              Switch.adaptive(
                value: controller.saveCard,
                activeTrackColor: theme.primaryColor ?? Theme.of(context).colorScheme.onSurface,
                onChanged: enabled ? (value) => controller.saveCard = value : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
