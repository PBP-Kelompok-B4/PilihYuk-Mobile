import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';

/// CookieRequest palsu dengan sesi dan cookie csrftoken terpasang.
/// get() (dipakai antrean publik) mencatat URL lalu mengembalikan reply() atau galat yang dilemparnya.
class FakeRequest implements CookieRequest {
  FakeRequest([this.reply]);

  final Object? Function()? reply;
  final urls = <String>[];
  int initCalls = 0;

  @override
  Map<String, String> headers = {'cookie': 'sessionid=s;csrftoken=t'};

  @override
  Map<String, Cookie> cookies = {
    'sessionid': Cookie('sessionid', 's', null),
    'csrftoken': Cookie('csrftoken', 't', null),
  };

  @override
  Map<String, dynamic> jsonData = {};

  @override
  bool loggedIn = false;

  @override
  bool initialized = true;

  @override
  Future<dynamic> init() async {
    initCalls++;
  }

  @override
  Future<dynamic> get(String url) {
    urls.add(url);
    return Future<dynamic>.microtask(reply!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Balasan JSON seperti DRF: application/json tanpa charset (http >= 1.4 membacanya sebagai UTF-8).
http.Response jsonResponse(String json, int status, {bool charset = false}) =>
    http.Response.bytes(
      utf8.encode(json),
      status,
      headers: {
        'content-type': charset
            ? 'application/json; charset=utf-8'
            : 'application/json',
      },
    );

/// Halaman galat HTML Django, mis. 500 atau URL salah saat DEBUG.
http.Response htmlResponse(int status) => http.Response(
  '<!DOCTYPE html><html><body><h1>Server Error (500)</h1></body></html>',
  status,
  headers: {'content-type': 'text/html; charset=utf-8'},
);

/// Menjalankan body dengan setiap klien http diganti MockClient. Hasil: semua permintaan yang dikirim.
Future<List<http.Request>> withMockServer(
  http.Response Function(http.Request request) reply,
  Future<void> Function() body,
) async {
  final log = <http.Request>[];
  await http.runWithClient(
    body,
    () => MockClient((request) async {
      log.add(request);
      return reply(request);
    }),
  );
  return log;
}
