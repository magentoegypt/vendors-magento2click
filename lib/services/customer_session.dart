import 'dart:convert';

import 'package:http/http.dart' as http;

import '../common/constants.dart';
import '../common/events.dart';
import '../data/boxes.dart';
import '../generated/l10n.dart';

/// What the shopper sees when their login has run out.
String get sessionExpiredMessage =>
    '${S.current.sessionExpired}. ${S.current.loginToContinue}';

/// Magento's refusal of a token it no longer accepts, as REST sends it: the
/// untranslated template, with the resource in `parameters`.
const _refusedTemplate = "The consumer isn't authorized to access %resources.";

/// [HttpHooks.onUnauthorized] for Magento: ends the customer's session when
/// Magento refuses their token.
///
/// Customer tokens live 24 hours (webapi/jwtauth/customer_expiration). After
/// that every `self` route answers 401, and each screen showed Magento's
/// "The consumer isn't authorized to access self" while the app still looked
/// logged in. Now the session ends once, the login screen opens on top, and
/// the caller gets [sessionExpiredMessage] in place of Magento's text.
///
/// Only that refusal, of the stored customer token on a `self` route, counts.
/// Magento also answers 401 to a wrong current password when changing the
/// password or email, and integration-token calls can 401 as well; neither
/// means the login has expired.
http.Response? handleExpiredCustomerToken(http.Response response) {
  final token = UserBox().userInfo?.cookie;
  if (token == null || token.isEmpty) return null;
  // BaseRequest.headers is case-insensitive.
  if (response.request?.headers['Authorization'] != 'Bearer $token') {
    return null;
  }
  if (!isSelfRefusal(response.body)) return null;

  eventBus.fire(EventExpiredCookie(
    isRequiredLogin: true,
    errMsg: sessionExpiredMessage,
  ));
  return http.Response(
    jsonEncode({'message': sessionExpiredMessage}),
    401,
    request: response.request,
    headers: {
      ...response.headers,
      'content-type': 'application/json; charset=utf-8',
    },
  );
}

/// Whether [body] is Magento refusing access to a customer's own (`self`)
/// resources.
bool isSelfRefusal(String body) {
  try {
    final json = jsonDecode(body);
    if (json is! Map || json['message'] != _refusedTemplate) return false;
    final params = json['parameters'];
    return params is Map && params['resources'] == 'self';
  } catch (_) {
    return false;
  }
}
