import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';

import 'data_correction_fakes.dart';

const base = '$baseUrl/api/v1/corrections';

// Balasan asli API dari data tes Django; daftar panjang dipotong.
const product =
    '{"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true}';
const correctionJson =
    '{"id": 1, "product": $product, "status": "pending", "status_label": "Menunggu", "is_withdrawable": true, '
    '"created_at": "2026-11-24T06:16:06.274529Z", "items": [{"id": 2, "field_name": "sodium_100g", "label": "Natrium (mg/100 g)", '
    '"old_value": 0.78, "proposed_value": 0.5, "old_display": "780", "proposed_display": "500", "status": "pending", '
    '"status_label": "Menunggu", "review_note": ""}]}';
const rowJson =
    '{"id": 2, "correction_id": 1, "product": $product, "submitted_by": "Budi", '
    '"created_at": "2026-11-24T06:16:06.274529Z", "field_name": "sodium_100g", "label": "Natrium (mg/100 g)", '
    '"old_value": 0.78, "proposed_value": 0.5, "current_value": 0.78, "old_display": "780", "proposed_display": "500", '
    '"current_display": "780", "status": "pending", "status_label": "Menunggu", "review_note": "", "stale": false}';
const formJson =
    '{"product": $product, "focus": ["fiber_100g"], "correctable_fields": [{"field_name": "fiber_100g", '
    '"label": "Serat (g/100 g)", "group": "Gizi per 100 g", "type": "number", "current_value": null, "current_display": null, '
    '"display_factor": 1, "help_text": "Angka dalam g per 100 g, tanpa pemisah ribuan. Contoh: 7,5."}]}';
const mineJson =
    '{"count": 1, "page": 1, "page_size": 10, "num_pages": 1, "next_page": null, "previous_page": null, '
    '"results": [$correctionJson]}';
const moderationJson =
    '{"count": 1, "page": 1, "page_size": 20, "num_pages": 1, "next_page": null, "previous_page": null, '
    '"tab": "antrean", "field": null, "status": null, "tab_options": [{"key": "antrean", "label": "Antrean koreksi"}], '
    '"field_options": [{"key": "fiber_100g", "label": "Serat (g/100 g)"}], "status_options": [], '
    '"stats": {"pending": 1, "approved": 0, "rejected": 0}, "results": [$rowJson]}';
const guideJson =
    '{"fields": [{"field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "kind": "Angka desimal", '
    '"rules": ["Diisi dalam mg; produk menyimpannya dalam gram (dibagi 1000)."]}]}';
const reviewJson =
    '{"item": $rowJson, "correction": {"id": 1, "status": "pending", "status_label": "Menunggu"}, '
    '"product": {"id": 1, "field_name": "sodium_100g", "value": 0.5, "display": "500"}, "stale": true, '
    '"message": "Natrium (mg/100 g) untuk Sarimi Isi 2 Goreng disetujui; data produk sudah diperbarui."}';

/// Menunggu call dan mengembalikan ApiError yang dilemparnya.
Future<ApiError> caught(Future<Object?> call) async {
  try {
    await call;
  } on ApiError catch (error) {
    return error;
  }
  fail('ApiError tidak dilempar');
}

void expectWriteHeaders(http.Request request) {
  expect(request.headers['X-CSRFToken'], 't');
  expect(request.headers['Referer'], '$baseUrl/');
  expect(request.headers['cookie'], 'sessionid=s;csrftoken=t');
  expect(request.headers['content-type'], startsWith('application/json'));
}

void main() {
  late FakeRequest fake;
  late CorrectionApi api;

  setUp(() {
    fake = FakeRequest();
    api = CorrectionApi(fake);
  });

  group('reads use GET with the session cookie', () {
    test('me', () async {
      final log = await withMockServer(
        (_) => jsonResponse('{"logged_in": true, "is_staff": true}', 200),
        () async {
          final viewer = await api.me();
          expect([viewer.loggedIn, viewer.isStaff], [true, true]);
        },
      );
      final request = log.single;
      expect([request.method, request.url.toString()], ['GET', '$base/me/']);
      expect(request.headers['cookie'], 'sessionid=s;csrftoken=t');
      expect(request.headers.containsKey('X-CSRFToken'), isFalse);
      expect(fake.initCalls, 1);
    });

    test('fetchForm sends focus as repeated field', () async {
      final log = await withMockServer(
        (_) => jsonResponse(formJson, 200),
        () async {
          final form = await api.fetchForm(
            1,
            focus: ['fiber_100g', 'sodium_100g'],
          );
          expect(
            [form.product.id, form.focus, form.fields.single.fieldName],
            [
              1,
              ['fiber_100g'],
              'fiber_100g',
            ],
          );
          await api.fetchForm(1);
        },
      );
      expect(
        [for (final request in log) request.url.toString()],
        [
          '$base/products/1/form/?field=fiber_100g&field=sodium_100g',
          '$base/products/1/form/',
        ],
      );
    });

    test('mine and detail', () async {
      final log = await withMockServer(
        (request) => jsonResponse(
          request.url.path.endsWith('/mine/') ? mineJson : correctionJson,
          200,
        ),
        () async {
          final list = await api.mine();
          expect([list.count, list.results.single.id], [1, 1]);
          await api.mine(page: 2);
          await api.mine(page: 1);
          final correction = await api.detail(1);
          expect(
            [correction.status, correction.items.single.proposedDisplay],
            [CorrectionStatus.pending, '500'],
          );
        },
      );
      expect(
        [for (final request in log) request.url.toString()],
        ['$base/mine/', '$base/mine/?page=2', '$base/mine/', '$base/mine/1/'],
      );
    });

    test('moderation, guide and one item', () async {
      final log = await withMockServer(
        (request) {
          final path = request.url.path;
          if (path.endsWith('/guide/')) return jsonResponse(guideJson, 200);
          if (path.contains('/items/')) return jsonResponse(rowJson, 200);
          return jsonResponse(moderationJson, 200);
        },
        () async {
          final queue = await api.moderation();
          expect(
            [queue.tab, queue.stats.pending, queue.results.single.submittedBy],
            ['antrean', 1, 'Budi'],
          );
          await api.moderation(
            tab: 'semua',
            field: 'fiber_100g',
            status: 'rejected',
            page: 2,
          );
          final guide = await api.guide();
          expect(guide.single.fieldName, 'sodium_100g');
          final row = await api.moderationItem(2);
          expect([row.id, row.currentDisplay], [2, '780']);
        },
      );
      expect(
        [for (final request in log) request.url.toString()],
        [
          '$base/moderation/',
          '$base/moderation/?tab=semua&field=fiber_100g&status=rejected&page=2',
          '$base/moderation/guide/',
          '$base/moderation/items/2/',
        ],
      );
      expect([for (final request in log) request.method], everyElement('GET'));
    });
  });

  group('writes use sendJson with the CSRF token and Referer', () {
    test('submit posts product and items', () async {
      final log = await withMockServer(
        (_) => jsonResponse(correctionJson, 201),
        () async {
          final correction = await api.submit(1, {
            'fiber_100g': '2,5',
            'sodium_100g': '500',
          });
          expect([correction.id, correction.isWithdrawable], [1, true]);
        },
      );
      final request = log.single;
      expect([request.method, request.url.toString()], ['POST', '$base/mine/']);
      expectWriteHeaders(request);
      expect(jsonDecode(request.body), {
        'product': 1,
        'items': [
          {'field_name': 'fiber_100g', 'proposed_value': '2,5'},
          {'field_name': 'sodium_100g', 'proposed_value': '500'},
        ],
      });
    });

    test('withdraw deletes and accepts 204 without a body', () async {
      final log = await withMockServer((_) => http.Response('', 204), () async {
        await api.withdraw(1);
      });
      final request = log.single;
      expect(
        [request.method, request.url.toString(), request.body],
        ['DELETE', '$base/mine/1/', ''],
      );
      expectWriteHeaders(request);
    });

    test('review patches status and review_note', () async {
      final log = await withMockServer(
        (_) => jsonResponse(reviewJson, 200),
        () async {
          final result = await api.review(2, CorrectionStatus.approved);
          expect(
            [result.item.id, result.productDisplay, result.stale],
            [2, '500', true],
          );
          await api.review(
            2,
            CorrectionStatus.rejected,
            note: 'Tidak sesuai label.',
          );
        },
      );
      expect(
        [for (final request in log) '${request.method} ${request.url}'],
        ['PATCH $base/moderation/items/2/', 'PATCH $base/moderation/items/2/'],
      );
      expectWriteHeaders(log.first);
      expect(jsonDecode(log.first.body), {
        'status': 'approved',
        'review_note': '',
      });
      expect(jsonDecode(log.last.body), {
        'status': 'rejected',
        'review_note': 'Tidak sesuai label.',
      });
    });
  });

  group('errors become ApiError', () {
    test('400 keeps fields', () async {
      await withMockServer(
        (_) => jsonResponse(
          '{"detail": "Periksa kembali isian koreksi.", "code": "validation_error", '
          '"fields": {"nova_group": ["Grup NOVA harus bilangan bulat 1 sampai 4."]}}',
          400,
        ),
        () async {
          final error = await caught(api.submit(1, {'nova_group': '5'}));
          expect(
            [error.status, error.code, error.message],
            [400, 'validation_error', 'Periksa kembali isian koreksi.'],
          );
          expect(
            error.fieldError('nova_group'),
            'Grup NOVA harus bilangan bulat 1 sampai 4.',
          );
        },
      );
    });

    test('403, 404 and 409 keep the status and message', () async {
      final replies = {
        '/api/v1/corrections/mine/': jsonResponse(
          '{"detail": "Silakan masuk terlebih dahulu.", "code": "authentication_required"}',
          403,
        ),
        '/api/v1/corrections/mine/7/': jsonResponse(
          '{"detail": "Pengajuan tidak ditemukan.", "code": "correction_not_found"}',
          404,
        ),
        '/api/v1/corrections/mine/1/': jsonResponse(
          '{"detail": "Pengajuan ini sudah mulai ditinjau sehingga tidak bisa ditarik.", "code": "not_withdrawable"}',
          409,
        ),
        '/api/v1/corrections/moderation/items/2/': jsonResponse(
          '{"detail": "CSRF Failed: CSRF token missing."}',
          403,
        ),
      };
      await withMockServer((request) => replies[request.url.path]!, () async {
        final login = await caught(api.mine());
        expect(
          [login.status, login.needsLogin, login.message],
          [403, true, 'Silakan masuk terlebih dahulu.'],
        );
        final missing = await caught(api.detail(7));
        expect(
          [missing.status, missing.code, missing.message],
          [404, 'correction_not_found', 'Pengajuan tidak ditemukan.'],
        );
        final reviewed = await caught(api.withdraw(1));
        expect([reviewed.status, reviewed.code], [409, 'not_withdrawable']);
        expect(
          reviewed.message,
          'Pengajuan ini sudah mulai ditinjau sehingga tidak bisa ditarik.',
        );
        final csrf = await caught(api.review(2, CorrectionStatus.approved));
        expect([csrf.status, csrf.code, csrf.needsLogin], [403, null, false]);
        expect(csrf.message, ApiError.defaultMessage(403));
      });
    });

    test('500 with a JSON body uses the server message', () async {
      await withMockServer(
        (_) => jsonResponse('{"detail": "Internal error"}', 500),
        () async {
          final error = await caught(api.mine());
          expect(
            [error.status, error.message],
            [500, 'Server sedang bermasalah. Coba lagi nanti.'],
          );
        },
      );
    });

    test('an HTML page or a non-object body is a server error', () async {
      await withMockServer(
        (request) {
          if (request.method == 'GET' && request.url.path.endsWith('/mine/')) {
            return jsonResponse('[1, 2]', 200);
          }
          return htmlResponse(500);
        },
        () async {
          final calls = <Future<Object?> Function()>[
            () => api.moderation(),
            () => api.submit(1, {'brand': 'X'}),
            () => api.mine(),
          ];
          for (final call in calls) {
            final error = await caught(call());
            expect(
              [error.status, error.message],
              [0, 'Server sedang bermasalah. Coba lagi nanti.'],
            );
          }
        },
      );
    });

    test('network failures are status 0', () async {
      await withMockServer(
        (_) => throw http.ClientException('Connection refused'),
        () async {
          final calls = <Future<Object?> Function()>[
            () => api.me(),
            () => api.withdraw(1),
          ];
          for (final call in calls) {
            final error = await caught(call());
            expect([error.status, error.isNetwork], [0, true]);
            expect(error.message, ApiError.defaultMessage(0));
          }
        },
      );
    });
  });

  test('UTF-8 JSON with and without charset keeps · and ×', () async {
    final body = correctionJson.replaceFirst(
      'Sarimi Isi 2 Goreng',
      'Kopi · Susu ×2',
    );
    for (final charset in [false, true]) {
      await withMockServer(
        (_) => jsonResponse(body, 200, charset: charset),
        () async {
          expect((await api.detail(1)).product.productName, 'Kopi · Susu ×2');
        },
      );
    }
    await withMockServer((_) => jsonResponse(body, 201), () async {
      expect(
        (await api.submit(1, {'brand': 'X'})).product.productName,
        'Kopi · Susu ×2',
      );
    });
  });
}
