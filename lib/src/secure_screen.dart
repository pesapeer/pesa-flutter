import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps the card screen out of screenshots, screen recordings and the app
/// switcher: FLAG_SECURE on Android, a secure overlay on iOS. Wrap the
/// route that shows [PesaCardForm] in it.
class PesaSecureScreen extends StatefulWidget {
  const PesaSecureScreen({super.key, required this.child});

  final Widget child;

  static const MethodChannel channel = MethodChannel('pesa_checkout/secure');

  @override
  State<PesaSecureScreen> createState() => _PesaSecureScreenState();
}

class _PesaSecureScreenState extends State<PesaSecureScreen> {
  @override
  void initState() {
    super.initState();
    _set(true);
  }

  @override
  void dispose() {
    _set(false);
    super.dispose();
  }

  Future<void> _set(bool on) async {
    if (kIsWeb) return;
    try {
      await PesaSecureScreen.channel.invokeMethod<void>(on ? 'enable' : 'disable');
    } on MissingPluginException {
      // Desktop and tests: nothing to secure.
    } on PlatformException catch (e) {
      debugPrint('pesa_checkout: secure screen ${on ? 'on' : 'off'} failed: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
