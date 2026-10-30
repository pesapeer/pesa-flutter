import 'package:flutter/material.dart';
import 'package:pesa_checkout/pesa_checkout.dart';

/// Paste an intent id and client secret from your backend's
/// `POST /v1/intents` answer, then pay with a Tribe test card.
void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'pesa_checkout example',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF1C3FAA), useMaterial3: true),
        home: const IntentPage(),
      );
}

class IntentPage extends StatefulWidget {
  const IntentPage({super.key});

  @override
  State<IntentPage> createState() => _IntentPageState();
}

class _IntentPageState extends State<IntentPage> {
  final _url = TextEditingController(text: 'https://checkout.pesa.co');
  final _intent = TextEditingController();
  final _secret = TextEditingController();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pesa checkout')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'Checkout URL')),
          const SizedBox(height: 12),
          TextField(controller: _intent, decoration: const InputDecoration(labelText: 'Intent id')),
          const SizedBox(height: 12),
          TextField(controller: _secret, decoration: const InputDecoration(labelText: 'Client secret'), obscureText: true),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PayPage(
                checkout: PesaCheckout(checkoutUrl: _url.text.trim()),
                intentId: _intent.text.trim(),
                clientSecret: _secret.text.trim(),
              ),
            )),
            child: const Text('Open card form'),
          ),
        ]),
      );
}

class PayPage extends StatefulWidget {
  const PayPage({super.key, required this.checkout, required this.intentId, required this.clientSecret});

  final PesaCheckout checkout;
  final String intentId;
  final String clientSecret;

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  final _form = PesaCardFormController();
  CheckoutSession? _session;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.checkout.session(widget.intentId, widget.clientSecret).then(
          (s) => setState(() => _session = s),
          onError: (Object e) => setState(() => _error = '$e'),
        );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final card = _form.details();
    if (card == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.checkout.payWithCard(widget.intentId, widget.clientSecret, card, email: _form.emailText);
      if (!mounted) return;
      final text = r.isSuccess
          ? 'Paid — intent ${r.state}'
          : r.isDeclined
              ? 'Declined: ${r.failureReason ?? r.attempt?.state}'
              : 'Ended in ${r.state} / ${r.attempt?.state}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      if (r.isSuccess) Navigator.of(context).pop();
    } on PesaCheckoutException catch (e) {
      setState(() => _error = e.message);
    } finally {
      _form.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return PesaSecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(s?.merchant.displayName.isNotEmpty == true ? s!.merchant.displayName : 'Pay by card')),
        body: s == null
            ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text('${s.amount} ${s.currency}', style: Theme.of(context).textTheme.headlineMedium),
                if (s.description.isNotEmpty) Text(s.description),
                const SizedBox(height: 20),
                PesaCardForm(controller: _form, needsEmail: s.needsEmail, autofocus: true),
                const SizedBox(height: 20),
                PesaPayButton(controller: _form, amount: s.amount, currency: s.currency, busy: _busy, onPressed: _pay),
                if (_error != null)
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              ]),
      ),
    );
  }
}
