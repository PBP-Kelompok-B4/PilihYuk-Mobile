import 'package:flutter_test/flutter_test.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:pilihyuk_mobile/api.dart';
import 'package:pilihyuk_mobile/config.dart';

void main() {
  test('writeHeaders sends the session cookie, the CSRF token and a Referer', () {
    final request = CookieRequest()
      ..headers['cookie'] = 'sessionid=s;csrftoken=t'
      ..cookies['csrftoken'] = Cookie('csrftoken', 't', null);
    final headers = writeHeaders(request);
    expect(headers['cookie'], 'sessionid=s;csrftoken=t');
    expect(headers['X-CSRFToken'], 't');
    expect(headers['Referer'], '$baseUrl/');
    expect(writeHeaders(CookieRequest()).containsKey('X-CSRFToken'), isFalse);
  });
}
