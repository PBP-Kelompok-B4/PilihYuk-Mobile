import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:pilihyuk_mobile/config.dart';

// CookieRequest stores Django's csrftoken cookie but never sends it back as a header,
// and Django checks the Referer on HTTPS writes.
Map<String, String> writeHeaders(CookieRequest request) => {
      ...request.headers,
      'Content-Type': 'application/json; charset=UTF-8',
      'Referer': '$baseUrl/',
      if (request.cookies['csrftoken'] case final token?) 'X-CSRFToken': token.value,
    };

/// Sends a POST, PUT, PATCH or DELETE to a session-authenticated endpoint.
/// `data` is null for an empty reply (204). A non-JSON reply throws FormatException.
Future<({int status, dynamic data})> sendJson(
    CookieRequest request, String method, String url, [Object? body]) async {
  await request.init();
  final send = http.Request(method, Uri.parse(url))
    ..headers.addAll(writeHeaders(request))
    ..body = body == null ? '' : jsonEncode(body);
  final response = await http.Response.fromStream(await send.send());
  return (
    status: response.statusCode,
    data: response.body.isEmpty ? null : jsonDecode(response.body),
  );
}
