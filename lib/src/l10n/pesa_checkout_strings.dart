/// The SDK's text in en, fr, fr-CA and zh-Hans.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

import '../card.dart';
import 'strings_en.dart';
import 'strings_fr.dart';
import 'strings_fr_ca.dart';
import 'strings_zh_hans.dart';

/// Every user-visible string the SDK draws or puts in an exception.
///
/// The language is the first supported one of: the `locale` the host
/// passes, the session's `locale`, the app's locale, the device locale.
/// English otherwise.
class PesaCheckoutStrings {
  const PesaCheckoutStrings._(this.tag, this._text, [this._parent]);

  static const en = PesaCheckoutStrings._('en', stringsEn);
  static const fr = PesaCheckoutStrings._('fr', stringsFr);
  static const frCA = PesaCheckoutStrings._('fr-CA', stringsFrCa, fr);
  static const zhHans = PesaCheckoutStrings._('zh-Hans', stringsZhHans);

  static const all = [en, fr, frCA, zhHans];

  /// en, fr, fr-CA or zh-Hans.
  final String tag;
  final Map<String, String> _text;

  /// Where a key missing from [_text] comes from: fr for fr-CA.
  final PesaCheckoutStrings? _parent;

  String? _lookup(String key) => _text[key] ?? _parent?._lookup(key);

  Locale get locale => switch (tag) {
        'fr-CA' => const Locale('fr', 'CA'),
        'zh-Hans' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        _ => Locale(tag),
      };

  /// The supported tag for a BCP 47 tag, or null. A close tag is mapped:
  /// en-GB → en, fr-BE → fr, fr-CA → fr-CA, zh, zh-CN, zh-Hant → zh-Hans.
  static String? supportedTag(String? tag) {
    if (tag == null) return null;
    final parts = tag.trim().toLowerCase().split(RegExp('[-_]'));
    return switch (parts.first) {
      'en' => 'en',
      'fr' => parts.skip(1).contains('ca') ? 'fr-CA' : 'fr',
      'zh' => 'zh-Hans',
      _ => null,
    };
  }

  /// The strings for [tag]; English when it is not supported.
  static PesaCheckoutStrings resolve(String? tag) {
    final supported = supportedTag(tag);
    return all.firstWhere((s) => s.tag == supported, orElse: () => en);
  }

  /// The first supported of [locale], [sessionLocale] and [device]; the
  /// platform locale when [device] is null; English otherwise.
  static PesaCheckoutStrings pick({Locale? locale, String? sessionLocale, Locale? device}) {
    final tag = supportedTag(locale?.toLanguageTag()) ??
        supportedTag(sessionLocale) ??
        (device ?? ui.PlatformDispatcher.instance.locale).toLanguageTag();
    return resolve(tag);
  }

  /// [pick] with the app's locale from [context].
  static PesaCheckoutStrings of(BuildContext context, {Locale? locale, String? sessionLocale}) =>
      pick(locale: locale, sessionLocale: sessionLocale, device: Localizations.maybeLocaleOf(context));

  String _get(String key, [Map<String, String> args = const {}]) {
    var text = _lookup(key) ?? stringsEn[key]!;
    args.forEach((name, value) => text = text.replaceAll('{$name}', value));
    return text;
  }

  String get cardNumber => _get('field.cardNumber');
  String get expiryPlaceholder => _get('field.expiry');
  String securityCodePlaceholder(CardBrand brand) => _get(brand == CardBrand.amex ? 'field.cid' : 'field.cvv');
  String get nameOnCard => _get('field.nameOnCard');
  String get email => _get('field.email');
  String get securityCode => _get('field.securityCode');
  String get securityCodeOptional => _get('field.securityCodeOptional');

  /// The brand's name; a generic word for an unknown brand.
  String brandName(CardBrand brand) => brand == CardBrand.unknown ? _get('card.generic') : brand.label;

  String expires(String date) => _get('saved.expires', {'date': date});
  String get expired => _get('saved.expired');
  String savedCardLabel(CardBrand brand, String last4, String date) =>
      _get('saved.label', {'brand': brandName(brand), 'last4': last4, 'date': date});
  String savedCardExpiredLabel(CardBrand brand, String last4) =>
      _get('saved.labelExpired', {'brand': brandName(brand), 'last4': last4});
  String get useAnotherCard => _get('saved.useAnother');
  String get saveCard => _get('saved.saveCard');

  String get pay => _get('pay');

  /// "Pay £25.00"; [amount] is a decimal string such as the session's.
  String payAmount(String amount, String currency) => _get('pay.amount', {'amount': money(amount, currency)});

  String get numberEmpty => _get('invalid.numberEmpty');
  String get digitsOnly => _get('invalid.digitsOnly');
  String get numberIncomplete => _get('invalid.numberIncomplete');
  String get numberInvalid => _get('invalid.number');
  String get expiryFormat => _get('invalid.expiryFormat');
  String get expiryMonth => _get('invalid.expiryMonth');
  String get cardExpired => _get('invalid.expired');
  String get expiryYear => _get('invalid.expiryYear');
  String codeOnFront(int digits) => _get('invalid.codeFront', {'n': '$digits'});
  String codeOnBack(int digits) => _get('invalid.codeBack', {'n': '$digits'});
  String get codeEmpty => _get('invalid.code');
  String get holderNameInvalid => _get('invalid.holderName');
  String get emailInvalid => _get('invalid.email');

  /// The text for a `PesaCheckoutException.code`. [fallback] (the
  /// gateway's sentence) for a code the SDK does not know, else a generic
  /// line.
  String errorMessage(String code, {String? fallback}) =>
      _lookup('error.$code') ?? fallback ?? _get('error.generic');

  /// [amount] (a decimal string, "1234.5") in [currency] as this locale
  /// writes it: £1,234.50 in en and zh-Hans, 1 234,50 £ in fr and fr-CA
  /// (narrow no-break spaces). The fraction digits are kept as given.
  String money(String amount, String currency) {
    final french = tag.startsWith('fr');
    final trimmed = amount.trim();
    final negative = trimmed.startsWith('-');
    final parts = (negative ? trimmed.substring(1) : trimmed).split('.');
    parts[0] = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => french ? '\u202F' : ',');
    final number = parts.join(french ? ',' : '.');
    final code = currency.toUpperCase();
    final symbol = _lookup('currency.$code');
    final sign = negative ? '-' : '';
    if (french) return '$sign$number\u202F${symbol ?? code}';
    return symbol == null ? '$sign$code\u00A0$number' : '$sign$symbol$number';
  }
}

/// Wires [PesaCheckoutStrings] into `MaterialApp.localizationsDelegates`.
/// The SDK's widgets do not need it; they read the app's locale anyway.
class PesaCheckoutLocalizations extends LocalizationsDelegate<PesaCheckoutStrings> {
  const PesaCheckoutLocalizations();

  static const delegate = PesaCheckoutLocalizations();

  static final supportedLocales = [for (final s in PesaCheckoutStrings.all) s.locale];

  @override
  bool isSupported(Locale locale) => PesaCheckoutStrings.supportedTag(locale.toLanguageTag()) != null;

  @override
  Future<PesaCheckoutStrings> load(Locale locale) =>
      SynchronousFuture(PesaCheckoutStrings.resolve(locale.toLanguageTag()));

  @override
  bool shouldReload(PesaCheckoutLocalizations old) => false;
}
