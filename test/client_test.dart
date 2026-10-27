import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pesa_checkout/pesa_checkout.dart';

const intent = 'int_01TEST';
const secret = 'cs_secret_value';

Map<String, Object?> session({String state = 'open', Map<String, Object?>? attempt, bool needsEmail = false}) => {
      'intentId': intent,
      'state': state,
      'amount': '25.00',
      'currency': 'GBP',
      'description': 'Order 42',
      'merchant': {'displayName': 'Pesa Test Shop'},
      'methods': ['card'],
      'needsEmail': needsEmail,
      'returnUrl': 'https://shop.example/return',
      'attempt': ?attempt,
      'expiresAt': '2026-10-24T07:00:00Z',
    };

CardDetails card() => CardDetails(number: '4012888888881881', expiry: const CardExpiry(12, 2028), securityCode: '111', holderName: 'Jo Bloggs');

/// A fake edge that answers from a script of session states, one per poll.
class FakeEdge {
  FakeEdge(this.script);

  final List<Map<String, Object?>> script;
  final requests = <http.Request>[];
  int polls = 0;

  http.Client client() => MockClient((req) async {
        requests.add(req);
        if (req.method == 'POST' && req.url.path == '/c/$intent/card') {
          final body = jsonDecode(req.body) as Map;
          if (body['clientSecret'] != secret) {
            return http.Response(jsonEncode({'error': {'code': 'not_found', 'message': 'This payment link is not valid.'}}), 404);
          }
          return http.Response(jsonEncode(script.first), 202, headers: {'content-type': 'application/json'});
        }
        if (req.method == 'GET' && req.url.path == '/c/$intent/session') {
          if (req.headers['X-Client-Secret'] != secret) {
            return http.Response(jsonEncode({'error': {'code': 'not_found', 'message': 'nope'}}), 404);
          }
          polls++;
          final i = polls.clamp(0, script.length - 1);
          return http.Response(jsonEncode(script[i]), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('not found', 404);
      });
}

PesaCheckout checkout(FakeEdge edge, {Future<bool> Function(Uri)? openBrowser, int tries = 60}) => PesaCheckout(
      checkoutUrl: 'https://checkout.test',
      httpClient: edge.client(),
      openBrowser: openBrowser ?? (_) async => true,
      pollInterval: Duration.zero,
      pollTries: tries,
      challengeCeiling: const Duration(seconds: 2),
    );

void main() {
  test('session reads with the secret header', () async {
    final edge = FakeEdge([session(needsEmail: true)]);
    final s = await checkout(edge).session(intent, secret);
    expect(s.intentId, intent);
    expect(s.needsEmail, isTrue);
    expect(s.merchant.displayName, 'Pesa Test Shop');
    expect(s.attempt, isNull);
    expect(edge.requests.single.headers['X-Client-Secret'], secret);
  });

  test('sale without 3DS: pending then captured settles the intent', () async {
    final edge = FakeEdge([
      session(attempt: {'state': 'pending'}),
      session(attempt: {'state': 'pending'}),
      session(state: 'settled', attempt: {'state': 'captured', 'card': {'brand': 'visa', 'last4': '1881'}}),
    ]);
    final r = await checkout(edge).payWithCard(intent, secret, card(), email: 'jo@example.com');
    expect(r.isSuccess, isTrue);
    expect(r.state, 'settled');
    expect(r.attempt?.last4, '1881');
    final post = edge.requests.first;
    final body = jsonDecode(post.body) as Map;
    expect(body['cardNumber'], '4012888888881881');
    expect(body['expiryMonth'], 12);
    expect(body['expiryYear'], 2028);
    expect(body['securityCode'], '111');
    expect(body['email'], 'jo@example.com');
    expect(body.containsKey('saveCard'), isFalse);
    expect(edge.polls, 2);
  });

  test('3DS: opens the challenge once, keeps polling, ends captured', () async {
    final opened = <Uri>[];
    final edge = FakeEdge([
      session(attempt: {'state': 'pending'}),
      session(attempt: {'state': 'requires_3ds', 'challengeUrl': 'https://checkout.test/c/$intent/challenge?t=x'}),
      session(attempt: {'state': 'requires_3ds', 'challengeUrl': 'https://checkout.test/c/$intent/challenge?t=x'}),
      session(attempt: {'state': 'pending'}),
      session(state: 'settled', attempt: {'state': 'captured'}),
    ]);
    final r = await checkout(edge, openBrowser: (u) async {
      opened.add(u);
      return true;
    }).payWithCard(intent, secret, card());
    expect(r.isSuccess, isTrue);
    expect(opened, [Uri.parse('https://checkout.test/c/$intent/challenge?t=x')]);
  });

  test('a decline leaves the intent open with the reason', () async {
    final edge = FakeEdge([
      session(attempt: {'state': 'pending'}),
      session(attempt: {'state': 'declined', 'declineCode': '051', 'failureReason': 'The card was declined.'}),
    ]);
    final r = await checkout(edge).payWithCard(intent, secret, card());
    expect(r.isSuccess, isFalse);
    expect(r.isDeclined, isTrue);
    expect(r.state, 'open');
    expect(r.failureReason, 'The card was declined.');
    expect(r.attempt?.declineCode, '051');
  });

  test('a refusal becomes PesaCheckoutException with the gateway code', () async {
    final edge = FakeEdge([session()]);
    await expectLater(
      checkout(edge).payWithCard(intent, 'wrong', card()),
      throwsA(isA<PesaCheckoutException>().having((e) => e.code, 'code', 'not_found').having((e) => e.status, 'status', 404)),
    );
  });

  test('transport failure becomes a transport exception', () async {
    final c = PesaCheckout(httpClient: MockClient((_) async => throw http.ClientException('boom')));
    await expectLater(c.session(intent, secret), throwsA(isA<PesaCheckoutException>().having((e) => e.code, 'code', 'transport')));
  });

  test('polling gives up with timeout', () async {
    final edge = FakeEdge([session(attempt: {'state': 'pending'})]);
    await expectLater(
      checkout(edge, tries: 3).payWithCard(intent, secret, card()),
      throwsA(isA<PesaCheckoutException>().having((e) => e.code, 'code', 'timeout')),
    );
  });

  test('a challenge that cannot be opened is an error', () async {
    final edge = FakeEdge([
      session(attempt: {'state': 'requires_3ds', 'challengeUrl': 'https://checkout.test/c/$intent/challenge?t=x'}),
    ]);
    await expectLater(
      checkout(edge, openBrowser: (_) async => false).payWithCard(intent, secret, card()),
      throwsA(isA<PesaCheckoutException>().having((e) => e.code, 'code', 'challenge_unavailable')),
    );
  });

  test('wallets are not available yet', () {
    expect(() => PesaCheckout(httpClient: MockClient((_) async => http.Response('', 404))).payWithWallet(intent, secret, WalletKind.applePay), throwsUnimplementedError);
  });
}
