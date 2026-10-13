// Tests for expired-login handling (Styleya backend API doc, 2026-10-13:
// "On a 401 from any self endpoint, log the customer in again").
//
// Customer tokens expire after 24 hours, after which every `self` route
// answers 401. The app showed Magento's raw "The consumer isn't authorized to
// access self" on whatever screen made the call and stayed "logged in".
// makeRequest now hands each 401 to HttpHooks.onUnauthorized, and the app's
// handleExpiredCustomerToken ends the session when the refused token is the
// customer's own.
//
// It must not end the session for other 401s. The catalog body below is a
// real response from styleya.net (2026-10-13), for an integration token that
// lacked the attributes resource. Magento also answers a wrong current
// password on change-password / change-email with a 401.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:inspireui/utils/http_client.dart';
import 'package:magentoegypt/services/customer_session.dart';

const _selfRefused = '{"message":"The consumer isn\'t authorized to access '
    '%resources.","parameters":{"resources":"self"}}';

void main() {
  tearDown(() => HttpHooks.onUnauthorized = null);

  group('makeRequest', () {
    test('hands a 401 to the hook and returns its replacement', () async {
      http.Response? seen;
      final replacement = http.Response('{"message":"Session Expired"}', 401);
      HttpHooks.onUnauthorized = (response) {
        seen = response;
        return replacement;
      };

      final result =
          await makeRequest(Future.value(http.Response(_selfRefused, 401)));

      expect(seen?.body, _selfRefused);
      expect(identical(result, replacement), isTrue);
    });

    test('passes the 401 through when the hook declines it', () async {
      HttpHooks.onUnauthorized = (_) => null;

      final result =
          await makeRequest(Future.value(http.Response(_selfRefused, 401)));

      expect(result.statusCode, 401);
      expect(result.body, _selfRefused);
    });

    test('returns the 401 untouched when no hook is set', () async {
      final result =
          await makeRequest(Future.value(http.Response(_selfRefused, 401)));

      expect(result.body, _selfRefused);
    });

    test('does not call the hook for other statuses', () async {
      var calls = 0;
      HttpHooks.onUnauthorized = (_) {
        calls++;
        return null;
      };

      await makeRequest(Future.value(http.Response('{}', 200)));
      await makeRequest(Future.value(http.Response('{}', 400)));

      expect(calls, 0);
    });
  });

  group('isSelfRefusal', () {
    test('matches Magento refusing a customer token on a self route', () {
      expect(isSelfRefusal(_selfRefused), isTrue);
    });

    test('ignores the integration token being refused a catalog resource', () {
      expect(
        isSelfRefusal('{"message":"The consumer isn\'t authorized to access '
            '%resources.","parameters":{"resources":'
            '"Magento_Catalog::attributes_attributes"}}'),
        isFalse,
      );
    });

    test('ignores a wrong current password', () {
      expect(
        isSelfRefusal('{"message":"The password doesn\'t match this account. '
            'Verify the password and try again."}'),
        isFalse,
      );
    });

    test('ignores bodies that are not Magento JSON', () {
      expect(isSelfRefusal('<html><title>401</title></html>'), isFalse);
      expect(isSelfRefusal(''), isFalse);
    });
  });
}
