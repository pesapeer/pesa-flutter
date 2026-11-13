import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'l10n/pesa_checkout_strings.dart';

/// Where the 3-D Secure challenge shows.
enum PesaChallengeSurface {
  /// A full-screen page inside the app. The cardholder never leaves.
  inApp,

  /// The system's in-app browser, or an auth session the app launches. The
  /// checkout's return page then sends the browser to the intent's
  /// `returnUrl`, the app's own link.
  browser,
}

/// Shows the 3-D Secure challenge page to the cardholder.
///
/// [PesaCheckout] calls [open] once when the issuer asks for a challenge,
/// keeps polling the attempt meanwhile, and calls [close] once the attempt
/// has settled. The page itself is the checkout edge's, which posts to the
/// issuer and takes the cardholder back when they are done.
abstract class PesaChallengePresenter {
  /// Shows [url]. Completes with true once the page is up, false when it
  /// could not be shown at all. [onCancelled] is called if the cardholder
  /// dismisses the page before it finished.
  Future<bool> open(Uri url, {required void Function() onCancelled});

  /// Hides the page. A no-op when nothing is open.
  Future<void> close();

  /// The presenter for [surface]. [PesaChallengeSurface.inApp] needs
  /// [navigatorKey]; [PesaChallengeSurface.browser] takes an optional
  /// [launch] (an auth session, say) in place of the in-app browser.
  static PesaChallengePresenter of(
    PesaChallengeSurface surface, {
    GlobalKey<NavigatorState>? navigatorKey,
    Future<bool> Function(Uri url)? launch,
    Locale? locale,
  }) =>
      switch (surface) {
        PesaChallengeSurface.inApp => PesaWebViewChallenge(
            navigatorKey: navigatorKey ??
                (throw ArgumentError.value(surface, 'surface', 'PesaChallengeSurface.inApp needs a navigatorKey')),
            locale: locale,
          ),
        PesaChallengeSurface.browser => PesaBrowserChallenge(launch: launch),
      };
}

/// The challenge inside the app, in a full-screen web view. The default.
///
/// The page is opened on [navigatorKey]'s navigator and popped when the
/// issuer sends the cardholder back to the checkout, when the attempt
/// settles, or when the cardholder taps close. Only `http(s)` loads; the
/// return page's bounce to the app's own scheme is where the page ends.
class PesaWebViewChallenge implements PesaChallengePresenter {
  PesaWebViewChallenge({required this.navigatorKey, this.locale});

  final GlobalKey<NavigatorState> navigatorKey;
  final Locale? locale;

  _ChallengeRoute? _route;

  @override
  Future<bool> open(Uri url, {required void Function() onCancelled}) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null || !url.isScheme('https')) return false;
    await close();
    final route = _ChallengeRoute(url: url, locale: locale);
    _route = route;
    unawaited(navigator.push<void>(route).then((_) {
      if (identical(_route, route)) _route = null;
      if (route.endedByCardholder) onCancelled();
    }));
    return true;
  }

  @override
  Future<void> close() async {
    final route = _route;
    _route = null;
    if (route == null || !route.isActive) return;
    route.endedByCardholder = false;
    final navigator = route.navigator;
    if (navigator == null) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }
}

/// The challenge in the system's in-app browser (`url_launcher`). The
/// browser cannot be closed from here on every platform, so the cardholder
/// may be left on the return page; pass your own [launch] to open an auth
/// session instead.
class PesaBrowserChallenge implements PesaChallengePresenter {
  PesaBrowserChallenge({Future<bool> Function(Uri url)? launch}) : _launch = launch ?? _inAppBrowser;

  final Future<bool> Function(Uri url) _launch;

  static Future<bool> _inAppBrowser(Uri url) => launchUrl(url, mode: LaunchMode.inAppBrowserView);

  @override
  Future<bool> open(Uri url, {required void Function() onCancelled}) => _launch(url);

  @override
  Future<void> close() async {
    try {
      await closeInAppWebView();
    } on Object {
      // Nothing of ours is open, or the platform cannot close it.
    }
  }
}

/// What the challenge page does with a navigation.
enum ChallengeNavigation { load, block, finish }

/// Decides a navigation inside the challenge page.
///
/// The checkout's return page ends the challenge in whatever frame it
/// loads. Past that only the page itself can end it, by leaving `http(s)`
/// for the app's scheme. Issuer pages run 3-D Secure in iframes that start
/// on `about:blank`, `about:srcdoc` or `data:`; iOS reports those too, and
/// they are part of the challenge, not the end of it.
ChallengeNavigation challengeNavigation(Uri url, {required bool isMainFrame, required Uri returnUrl}) {
  final isReturn = url.host == returnUrl.host && url.path.replaceFirst(RegExp(r'/$'), '') == returnUrl.path;
  if (isReturn) return ChallengeNavigation.finish;
  if (url.isScheme('https') || url.isScheme('http')) return ChallengeNavigation.load;
  if (isMainFrame) return ChallengeNavigation.finish;
  const inFrame = {'about', 'data', 'blob'};
  return inFrame.contains(url.scheme) ? ChallengeNavigation.load : ChallengeNavigation.block;
}

class _ChallengeRoute extends MaterialPageRoute<void> {
  _ChallengeRoute({required Uri url, Locale? locale})
      : super(
          fullscreenDialog: true,
          builder: (_) => PesaChallengePage(url: url, locale: locale),
        );

  /// False once the checkout, not the cardholder, ended the page.
  bool endedByCardholder = true;
}

/// The full-screen page that hosts the challenge. [PesaWebViewChallenge]
/// pushes it; apps with their own navigation can push it themselves and
/// pop it when the attempt settles.
class PesaChallengePage extends StatefulWidget {
  const PesaChallengePage({super.key, required this.url, this.locale});

  /// The attempt's `challengeUrl`.
  final Uri url;
  final Locale? locale;

  @override
  State<PesaChallengePage> createState() => _PesaChallengePageState();
}

class _PesaChallengePageState extends State<PesaChallengePage> {
  late final WebViewController _controller;
  late final Uri _returnUrl;
  var _loading = true;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _returnUrl = widget.url.replace(
      path: widget.url.path.replaceFirst(RegExp(r'/challenge/?$'), '/return'),
      query: null,
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _decide,
        onPageFinished: (_) => _setLoading(false),
        onPageStarted: (_) => _setLoading(true),
      ))
      ..loadRequest(widget.url);
  }

  NavigationDecision _decide(NavigationRequest request) {
    final url = Uri.tryParse(request.url);
    if (url == null) return NavigationDecision.prevent;
    switch (challengeNavigation(url, isMainFrame: request.isMainFrame, returnUrl: _returnUrl)) {
      case ChallengeNavigation.load:
        return NavigationDecision.navigate;
      case ChallengeNavigation.block:
        return NavigationDecision.prevent;
      case ChallengeNavigation.finish:
        _finish();
        return NavigationDecision.prevent;
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    final route = ModalRoute.of(context);
    if (route is _ChallengeRoute) route.endedByCardholder = false;
    Navigator.of(context).pop();
  }

  void _setLoading(bool loading) {
    if (mounted && _loading != loading) setState(() => _loading = loading);
  }

  @override
  Widget build(BuildContext context) {
    final strings = PesaCheckoutStrings.of(context, locale: widget.locale);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.challengeTitle),
        leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
