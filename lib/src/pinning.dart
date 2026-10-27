import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// SPKI pinning: the SHA-256 of the server certificate's
/// SubjectPublicKeyInfo, base64 — the same value Android's network security
/// config and HPKP use (`openssl x509 -pubkey -noout | openssl pkey -pubin
/// -outform der | openssl dgst -sha256 -binary | base64`).
///
/// The pin is checked on the socket right after the TLS handshake and
/// before a single request byte is written, so a card number is never sent
/// to a host that does not hold Pesa's key. Chain validation against the
/// system roots still happens first; pinning narrows it, never replaces it.
class SpkiPin {
  SpkiPin._();

  /// The pin of [certificate].
  static String of(X509Certificate certificate) =>
      base64.encode(sha256.convert(subjectPublicKeyInfo(certificate.der)).bytes);

  /// Whether [certificate]'s key is one of [pins].
  static bool matches(X509Certificate certificate, Iterable<String> pins) {
    final pin = of(certificate);
    return pins.any((p) => p.trim() == pin);
  }

  /// Lifts the DER-encoded SubjectPublicKeyInfo out of a DER certificate.
  ///
  /// Certificate ::= SEQUENCE { tbsCertificate SEQUENCE { [0] version?,
  /// serialNumber, signature, issuer, validity, subject,
  /// subjectPublicKeyInfo, … }, … }.
  static Uint8List subjectPublicKeyInfo(Uint8List der) {
    final cert = _Der(der).sequence();
    final tbs = _Der(cert).sequence();
    final r = _Der(tbs);
    if (r.peekTag() == 0xa0) r.skip(); // version
    r.skip(); // serialNumber
    r.skip(); // signature
    r.skip(); // issuer
    r.skip(); // validity
    r.skip(); // subject
    return r.element();
  }
}

/// The smallest DER reader that can walk a certificate: tag, length, value.
class _Der {
  _Der(this.bytes);

  final Uint8List bytes;
  int _pos = 0;

  int peekTag() => bytes[_pos];

  /// Reads the next element and returns its contents, which must be a
  /// SEQUENCE.
  Uint8List sequence() {
    if (peekTag() != 0x30) throw const FormatException('expected SEQUENCE');
    return contents();
  }

  /// Returns the next whole element, header included.
  Uint8List element() {
    final start = _pos;
    contents();
    return Uint8List.sublistView(bytes, start, _pos);
  }

  void skip() => contents();

  Uint8List contents() {
    _pos++; // tag; multi-byte tags do not occur in a certificate's outer layers
    var len = bytes[_pos++];
    if (len & 0x80 != 0) {
      final n = len & 0x7f;
      if (n == 0 || n > 4) throw const FormatException('bad DER length');
      len = 0;
      for (var i = 0; i < n; i++) {
        len = (len << 8) | bytes[_pos++];
      }
    }
    if (_pos + len > bytes.length) throw const FormatException('DER element overruns');
    final out = Uint8List.sublistView(bytes, _pos, _pos + len);
    _pos += len;
    return out;
  }
}

/// An [HttpClient] whose connections to [host] are refused unless the
/// server's leaf key matches one of [pins]. Other hosts connect normally.
///
/// [context] is for tests that run their own server; production uses the
/// system roots.
HttpClient pinnedHttpClient({
  required String host,
  required List<String> pins,
  Duration connectTimeout = const Duration(seconds: 15),
  SecurityContext? context,
}) {
  final client = HttpClient(context: context)..connectionTimeout = connectTimeout;
  if (pins.isEmpty) return client;
  client.connectionFactory = (uri, proxyHost, proxyPort) async {
    if (uri.scheme != 'https' || uri.host != host) {
      if (uri.scheme == 'https') {
        return SecureSocket.startConnect(uri.host, uri.port, context: context);
      }
      return Socket.startConnect(uri.host, uri.port);
    }
    final task = await SecureSocket.startConnect(uri.host, uri.port, context: context);
    return ConnectionTask.fromSocket(
      task.socket.timeout(connectTimeout).then((socket) {
        final cert = socket.peerCertificate;
        if (cert == null || !SpkiPin.matches(cert, pins)) {
          socket.destroy();
          throw const HandshakeException('pesa_checkout: server key does not match a known pin');
        }
        return socket;
      }),
      task.cancel,
    );
  };
  return client;
}
