import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:pilihyuk_mobile/api.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';

/// GET berstatus untuk endpoint yang butuh sesi. request.get tidak memberi status code dan tidak ikut
/// http.runWithClient; balasan ini berbentuk sama dengan sendJson di lib/api.dart.
Future<({int status, dynamic data})> getJson(
  CookieRequest request,
  String url,
) async {
  await request.init();
  final response = await http.get(Uri.parse(url), headers: request.headers);
  return (
    status: response.statusCode,
    data: response.body.isEmpty ? null : jsonDecode(response.body),
  );
}

/// Penghubung CorrectionApi dengan halaman antrean yang sedang terbuka, satu per CookieRequest. Antrean ada di
/// bawah semua halaman modul, jadi ia yang menampilkan sheet login saat sesi habis. changed menandai tulis
/// yang berhasil (kirim, tarik, tinjau), supaya antrean dimuat ulang saat pengguna kembali.
class ModuleSession {
  ModuleSession(this._onSessionEnded);

  static final _sessions = <CookieRequest, ModuleSession>{};

  static ModuleSession? of(CookieRequest request) => _sessions[request];

  final Future<bool> Function() _onSessionEnded;
  Future<bool>? _pending;
  bool changed = false;

  void attach(CookieRequest request) {
    _sessions[request] = this;
  }

  void detach(CookieRequest request) {
    if (_sessions[request] == this) {
      _sessions.remove(request);
    }
  }

  /// Beberapa permintaan yang kena 403 bersamaan berbagi satu sheet. true = pengguna sudah masuk lagi.
  Future<bool> sessionEnded() =>
      _pending ??= _onSessionEnded().whenComplete(() => _pending = null);

  /// true sekali setelah ada perubahan, lalu kembali false.
  bool takeChanges() {
    final result = changed;
    changed = false;
    return result;
  }
}

/// Semua panggilan /api/v1/corrections/ selain antrean publik. Sukses (2xx) -> model; selain itu ApiError
/// (status 0 untuk galat jaringan atau balasan yang bukan JSON).
class CorrectionApi {
  CorrectionApi(this.request);

  final CookieRequest request;
  static const timeout = Duration(seconds: 20);

  Future<Viewer> me() => _get(_uri('me/'), Viewer.fromJson);

  Future<CorrectionFormData> fetchForm(
    int productId, {
    List<String> focus = const [],
  }) => _get(
    _uri('products/$productId/form/', {if (focus.isNotEmpty) 'field': focus}),
    CorrectionFormData.fromJson,
  );

  /// values: field_name -> isian apa adanya, mis. {"sodium_100g": "780"} (natrium dalam mg).
  Future<Correction> submit(int productId, Map<String, String> values) =>
      _write('POST', _uri('mine/'), Correction.fromJson, {
        'product': productId,
        'items': [
          for (final entry in values.entries)
            {'field_name': entry.key, 'proposed_value': entry.value},
        ],
      });

  Future<CorrectionList> mine({int page = 1}) => _get(
    _uri('mine/', {if (page > 1) 'page': '$page'}),
    CorrectionList.fromJson,
  );

  Future<Correction> detail(int id) =>
      _get(_uri('mine/$id/'), Correction.fromJson);

  Future<void> withdraw(int id) async {
    await _call(
      () => sendJson(request, 'DELETE', _uri('mine/$id/').toString()),
      (_) {},
    );
    _markChanged();
  }

  Future<ModerationQueue> moderation({
    String? tab,
    String? field,
    String? status,
    int page = 1,
  }) => _get(
    _uri('moderation/', {
      'tab': ?tab,
      'field': ?field,
      'status': ?status,
      if (page > 1) 'page': '$page',
    }),
    ModerationQueue.fromJson,
  );

  Future<List<FieldGuideEntry>> guide() =>
      _get(_uri('moderation/guide/'), FieldGuideEntry.listFromJson);

  Future<ModerationRow> moderationItem(int id) =>
      _get(_uri('moderation/items/$id/'), ModerationRow.fromJson);

  /// status: CorrectionStatus.approved atau CorrectionStatus.rejected. Catatan wajib saat menolak (dicek server).
  Future<ReviewResult> review(int itemId, String status, {String note = ''}) =>
      _write(
        'PATCH',
        _uri('moderation/items/$itemId/'),
        ReviewResult.fromJson,
        {'status': status, 'review_note': note},
      );

  static Uri _uri(String path, [Map<String, Object> query = const {}]) =>
      Uri.parse('$baseUrl/api/v1/corrections/$path')
          .replace(queryParameters: query.isEmpty ? null : query);

  Future<T> _get<T>(Uri uri, T Function(Map<String, dynamic>) parse) => _call(
    () => getJson(request, uri.toString()),
    (data) => parse(_object(data)),
  );

  Future<T> _write<T>(
    String method,
    Uri uri,
    T Function(Map<String, dynamic>) parse,
    Object body,
  ) async {
    final result = await _call(
      () => sendJson(request, method, uri.toString(), body),
      (data) => parse(_object(data)),
    );
    _markChanged();
    return result;
  }

  void _markChanged() => ModuleSession.of(request)?.changed = true;

  /// 403 authentication_required di tengah jalan: antrean menampilkan sheet login, lalu permintaan diulang
  /// sekali bila pengguna sudah masuk lagi. Tanpa antrean (mis. di tes satu halaman), galat diteruskan.
  Future<T> _call<T>(
    Future<({int status, dynamic data})> Function() send,
    T Function(Object? data) parse,
  ) async {
    try {
      return await _send(send, parse);
    } on ApiError catch (error) {
      final session = ModuleSession.of(request);
      if (!error.needsLogin ||
          session == null ||
          !await session.sessionEnded()) {
        rethrow;
      }
      return _send(send, parse);
    }
  }

  Future<T> _send<T>(
    Future<({int status, dynamic data})> Function() send,
    T Function(Object? data) parse,
  ) async {
    try {
      final response = await send().timeout(timeout);
      if (response.status < 200 || response.status > 299) {
        throw ApiError.fromResponse(response.status, response.data);
      }
      return parse(response.data);
    } on http.ClientException {
      throw ApiError(0, ApiError.defaultMessage(0));
    } on TimeoutException {
      throw ApiError(0, ApiError.defaultMessage(0));
    } on FormatException {
      // Balasan bukan JSON, mis. halaman galat HTML Django.
      throw ApiError(0, ApiError.defaultMessage(500));
    }
  }

  static Map<String, dynamic> _object(Object? data) =>
      data is Map<String, dynamic>
      ? data
      : throw const FormatException('Balasan bukan objek JSON.');
}
