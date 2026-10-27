import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesa_checkout/pesa_checkout.dart';
import 'package:pesa_checkout/src/pinning.dart';

Uint8List pemToDer(String pem) {
  final b64 = pem.split('\n').where((l) => l.isNotEmpty && !l.startsWith('-----')).join();
  return base64.decode(b64);
}

void main() {
  final certPem = File('test/fixtures/cert.pem').readAsStringSync();
  final keyPem = File('test/fixtures/key.pem').readAsStringSync();
  final expectedPin = File('test/fixtures/pin.txt').readAsStringSync().trim();

  test('SPKI lifted from DER hashes to the openssl pin', () {
    final spki = SpkiPin.subjectPublicKeyInfo(pemToDer(certPem));
    expect(base64.encode(sha256.convert(spki).bytes), expectedPin);
  });

  test('garbage is refused, not misread', () {
    expect(() => SpkiPin.subjectPublicKeyInfo(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });

  group('pinned client', () {
    late HttpServer server;
    var hits = 0;

    setUp(() async {
      final ctx = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(certPem))
        ..usePrivateKeyBytes(utf8.encode(keyPem));
      server = await HttpServer.bindSecure('127.0.0.1', 0, ctx);
      hits = 0;
      server.listen((req) {
        hits++;
        req.response
          ..write('ok')
          ..close();
      });
    });

    tearDown(() => server.close(force: true));

    SecurityContext trustFixture() => SecurityContext(withTrustedRoots: false)..setTrustedCertificatesBytes(utf8.encode(certPem));

    test('matching pin connects', () async {
      final c = pinnedHttpClient(host: '127.0.0.1', pins: ['bogus=', expectedPin], context: trustFixture());
      final res = await c.getUrl(Uri.parse('https://127.0.0.1:${server.port}/')).then((r) => r.close());
      expect(res.statusCode, 200);
      expect(hits, 1);
      c.close(force: true);
    });

    test('wrong pin never sends the request', () async {
      final c = pinnedHttpClient(host: '127.0.0.1', pins: ['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='], context: trustFixture());
      await expectLater(c.getUrl(Uri.parse('https://127.0.0.1:${server.port}/')), throwsA(isA<HandshakeException>()));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(hits, 0);
      c.close(force: true);
    });

    test('pin mismatch surfaces as pin_mismatch from PesaCheckout', () async {
      final c = PesaCheckout(
        checkoutUrl: 'https://127.0.0.1:${server.port}',
        httpClient: null,
        pins: const ['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
      );
      // The default transport uses the system roots, which do not include the
      // fixture; the handshake fails before the pin is read, and that too is
      // reported as a pin / handshake problem rather than a transport one.
      await expectLater(c.session('int_x', 's'), throwsA(isA<PesaCheckoutException>().having((e) => e.code, 'code', 'pin_mismatch')));
    });
  });
}
