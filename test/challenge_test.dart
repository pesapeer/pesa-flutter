import 'package:flutter_test/flutter_test.dart';
import 'package:pesa_checkout/src/challenge.dart';

void main() {
  final returnUrl = Uri.parse('https://checkout.test/c/int_1/return');

  ChallengeNavigation decide(String url, {bool isMainFrame = true}) =>
      challengeNavigation(Uri.parse(url), isMainFrame: isMainFrame, returnUrl: returnUrl);

  test('the issuer\'s pages load', () {
    expect(decide('https://acs.bank.test/challenge'), ChallengeNavigation.load);
    expect(decide('https://acs.bank.test/method', isMainFrame: false), ChallengeNavigation.load);
  });

  test('the return page ends the challenge in any frame', () {
    expect(decide('https://checkout.test/c/int_1/return'), ChallengeNavigation.finish);
    expect(decide('https://checkout.test/c/int_1/return/?cres=x'), ChallengeNavigation.finish);
    expect(decide('https://checkout.test/c/int_1/return', isMainFrame: false), ChallengeNavigation.finish);
  });

  test('the page leaving for the app\'s scheme ends the challenge', () {
    expect(decide('pesapeer://ipg-return'), ChallengeNavigation.finish);
  });

  test('3-D Secure iframes do not end the challenge', () {
    for (final url in ['about:blank', 'about:srcdoc', 'data:text/html,', 'blob:https://acs.bank.test/1']) {
      expect(decide(url, isMainFrame: false), ChallengeNavigation.load, reason: url);
    }
  });

  test('an iframe cannot open another app or end the challenge', () {
    expect(decide('bankapp://approve', isMainFrame: false), ChallengeNavigation.block);
  });
}
