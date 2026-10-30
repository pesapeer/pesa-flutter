import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:url_launcher/url_launcher.dart';

import 'card.dart';
import 'models.dart';
import 'pinning.dart';

/// Talks to the checkout edge for one app. Create one and keep it.
class PesaCheckout {
  /// [pins] are the SPKI pins of checkout.pesa.co. Production builds must
  /// set both current pins; an empty list turns pinning off and is for
  /// development against a local edge only. [httpClient] replaces the
  /// transport entirely (tests); pins are then not applied.
  PesaCheckout({
    String checkoutUrl = 'https://checkout.pesa.co',
    List<String> pins = const [],
    http.Client? httpClient,
    Future<bool> Function(Uri url)? openBrowser,
    Duration pollInterval = const Duration(milliseconds: 1500),
    int pollTries = 60,
    Duration challengeCeiling = const Duration(minutes: 5),
  })  : _base = Uri.parse(checkoutUrl),
        _pollInterval = pollInterval,
        _pollTries = pollTries,
        _challengeCeiling = challengeCeiling,
        _openBrowser = openBrowser ?? _launch,
        _http = httpClient ??
            IOClient(pinnedHttpClient(host: Uri.parse(checkoutUrl).host, pins: pins));

  final Uri _base;
  final http.Client _http;
  final Duration _pollInterval;
  final int _pollTries;
  final Duration _challengeCeiling;
  final Future<bool> Function(Uri url) _openBrowser;

  static Future<bool> _launch(Uri url) =>
      launchUrl(url, mode: LaunchMode.inAppBrowserView);

  Uri _url(String intentId, [String suffix = '']) =>
      _base.replace(path: '${_base.path}/c/$intentId$suffix');

  /// Reads the intent as the checkout sees it.
  Future<CheckoutSession> session(String intentId, String clientSecret) async {
    final res = await _send(() => _http.get(_url(intentId, '/session'), headers: {
          'Accept': 'application/json',
          'X-Client-Secret': clientSecret,
        }));
    return CheckoutSession.fromJson(_json(res));
  }

  /// Charges [card] against the intent and follows it to an outcome: polls
  /// the session, opens the 3-D Secure challenge in the system browser when
  /// the issuer asks, and returns when the attempt is no longer pending.
  ///
  /// [card] is cleared from this call's own copies once sent; clear the
  /// form's controllers yourself.
  ///
  /// [saveCard] is the payer's consent to keep the card for next time. The
  /// checkout honours it when the session says `canSaveCard`, and keeps the
  /// card once the charge succeeds.
  Future<CheckoutResult> payWithCard(
    String intentId,
    String clientSecret,
    CardDetails card, {
    String? email,
    bool saveCard = false,
  }) =>
      _payCard(intentId, clientSecret, {
        'cardNumber': card.number,
        'expiryMonth': card.expiry.month,
        'expiryYear': card.expiry.year,
        'securityCode': card.securityCode,
        'holderName': card.holderName,
        if (saveCard) 'saveCard': true,
      }, email);

  /// Charges a card from the session's `savedCards` and follows it to an
  /// outcome exactly as [payWithCard] does, 3-D Secure included.
  ///
  /// [token] is the saved card's token. Send [securityCode] when the
  /// session's `savedCardSecurityCode` is `required`, or when the payer
  /// typed one.
  Future<CheckoutResult> payWithSavedCard(
    String intentId,
    String clientSecret,
    String token, {
    String? securityCode,
    String? email,
  }) =>
      _payCard(intentId, clientSecret, {
        'savedCard': {
          'token': token,
          if (securityCode != null && securityCode.isNotEmpty) 'securityCode': securityCode.trim(),
        },
      }, email);

  Future<CheckoutResult> _payCard(
    String intentId,
    String clientSecret,
    Map<String, Object?> card,
    String? email,
  ) async {
    final body = <String, Object?>{
      'clientSecret': clientSecret,
      ...card,
      if (email != null && email.isNotEmpty) 'email': email.trim(),
    };
    final http.Response res;
    try {
      res = await _send(() => _http.post(_url(intentId, '/card'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode(body)));
    } finally {
      (card['savedCard'] as Map?)?.clear();
      card.clear();
      body.clear();
    }
    final first = CheckoutSession.fromJson(_json(res));
    return _follow(intentId, clientSecret, first);
  }

  /// Apple Pay / Google Pay. Phase 2: the wallet token goes to
  /// `POST /c/{intent}/wallet`.
  Future<CheckoutResult> payWithWallet(String intentId, String clientSecret, WalletKind wallet) {
    // TODO(phase 2): native sheets (PassKit / Google Pay API) and the wallet route.
    throw UnimplementedError('Wallet payments arrive in the next release.');
  }

  Future<CheckoutResult> _follow(String intentId, String clientSecret, CheckoutSession first) async {
    var s = first;
    var tries = 0;
    var challengeOpened = false;
    DateTime? challengeStarted;
    while (true) {
      final a = s.attempt;
      if (a == null || (!a.isPending && !a.requires3ds) || s.isClosed) {
        return CheckoutResult(intentId: intentId, state: s.state, attempt: a);
      }
      if (a.requires3ds && a.challengeUrl != null && !challengeOpened) {
        challengeOpened = true;
        challengeStarted = DateTime.now();
        if (!await _openBrowser(Uri.parse(a.challengeUrl!))) {
          throw const PesaCheckoutException('challenge_unavailable', 'The bank authentication page could not be opened.');
        }
      }
      tries++;
      final overCeiling = challengeStarted == null
          ? tries >= _pollTries
          : DateTime.now().difference(challengeStarted) > _challengeCeiling;
      if (overCeiling) {
        throw PesaCheckoutException('timeout', 'The payment is still being processed. Check with the merchant before paying again.', status: null);
      }
      await Future<void>.delayed(_pollInterval);
      s = await session(intentId, clientSecret);
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 30));
    } on HandshakeException catch (e) {
      throw PesaCheckoutException('pin_mismatch', e.message);
    } on SocketException catch (e) {
      throw PesaCheckoutException('transport', e.message);
    } on HttpException catch (e) {
      throw PesaCheckoutException('transport', e.message);
    } on http.ClientException catch (e) {
      throw PesaCheckoutException('transport', e.message);
    } on FormatException catch (e) {
      throw PesaCheckoutException('transport', e.message);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw _error(res);
  }

  static Map<String, dynamic> _json(http.Response res) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const PesaCheckoutException('transport', 'Unexpected answer from the checkout.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PesaCheckoutException('transport', 'Unexpected answer from the checkout.');
    }
    return decoded;
  }

  static PesaCheckoutException _error(http.Response res) {
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      final e = (j is Map && j['error'] is Map) ? j['error'] as Map : (j is Map ? j : const {});
      final code = e['code'] as String? ?? 'http_${res.statusCode}';
      final message = e['message'] as String? ?? 'The checkout refused the request.';
      return PesaCheckoutException(code, message, status: res.statusCode, field: e['field'] as String?);
    } catch (_) {
      return PesaCheckoutException('http_${res.statusCode}', 'The checkout refused the request.', status: res.statusCode);
    }
  }
}
