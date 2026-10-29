import 'package:flutter/material.dart';

import '../card.dart';

/// A drawn stand-in for a card brand's mark: a shape and a word, not the
/// brand's artwork. Nothing for [CardBrand.unknown].
class CardBrandMark extends StatelessWidget {
  const CardBrandMark({super.key, required this.brand, this.height = 20});

  final CardBrand brand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final h = height;
    final mark = switch (brand) {
      CardBrand.visa => _word('VISA', const Color(0xFF1A1F71), h * 0.78, italic: true),
      CardBrand.mastercard => SizedBox(
          width: h * 1.6,
          height: h,
          child: Stack(
            children: [
              _circle(h, const Color(0xFFEB001B)),
              Positioned(right: 0, child: _circle(h, const Color(0xE6F79E1B))),
            ],
          ),
        ),
      CardBrand.amex => _box(h, 'AMEX', const BoxDecoration(color: Color(0xFF2E77BC))),
      CardBrand.unionpay => _box(
          h,
          'UnionPay',
          const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE21836),
                Color(0xFFE21836),
                Color(0xFF00447C),
                Color(0xFF00447C),
                Color(0xFF007B84),
                Color(0xFF007B84),
              ],
              stops: [0, 0.34, 0.34, 0.67, 0.67, 1],
            ),
          ),
        ),
      CardBrand.unknown => null,
    };
    if (mark == null) return const SizedBox.shrink();
    return Semantics(
      label: brand.label,
      child: ExcludeSemantics(child: SizedBox(height: h, child: mark)),
    );
  }

  static Widget _word(String text, Color color, double size, {bool italic = false}) => Center(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: color,
            fontSize: size,
            height: 1,
            fontWeight: FontWeight.w900,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            letterSpacing: size * (italic ? -0.02 : 0.06),
          ),
        ),
      );

  static Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  static Widget _box(double h, String text, BoxDecoration decoration) => Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: h * 0.3),
        decoration: decoration.copyWith(borderRadius: BorderRadius.circular(h * 0.18)),
        child: _word(text, const Color(0xFFFFFFFF), h * 0.42),
      );
}
