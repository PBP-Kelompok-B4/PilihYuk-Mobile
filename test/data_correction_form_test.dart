import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_form_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';
import 'package:pilihyuk_mobile/screens/data_correction/data_correction_page.dart';

import 'data_correction_fakes.dart';

const base = '$baseUrl/api/v1/corrections';

// Empat field asli dari GET products/<pk>/form/ (data tes Django).
const fieldsJson = r'''
[{"field_name": "brand", "label": "Merek", "group": "Info produk", "type": "text", "current_value": "Sarimi",
  "current_display": "Sarimi", "display_factor": 1, "help_text": "Maksimal 255 karakter."},
 {"field_name": "nova_group", "label": "Grup NOVA", "group": "Tingkat pemrosesan", "type": "integer", "current_value": 4,
  "current_display": "4", "display_factor": 1,
  "help_text": "Bilangan bulat 1 sampai 4: 1 = tidak/minim diproses, 4 = ultra-proses."},
 {"field_name": "fiber_100g", "label": "Serat (g/100 g)", "group": "Gizi per 100 g", "type": "number", "current_value": null,
  "current_display": null, "display_factor": 1, "help_text": "Angka dalam g per 100 g, tanpa pemisah ribuan. Contoh: 7,5."},
 {"field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "group": "Gizi per 100 g", "type": "number",
  "current_value": 0.78, "current_display": "780", "display_factor": 1000,
  "help_text": "Angka dalam mg per 100 g, tanpa pemisah ribuan. Contoh: 780."}]
''';
const fieldNames = ['brand', 'nova_group', 'fiber_100g', 'sodium_100g'];

const queueJson = r'''
{"count": 1, "page": 1, "page_size": 20, "num_pages": 1, "next_page": null, "previous_page": null,
 "sort": "shelf", "missing": null, "shelf_available": true,
 "sort_options": [{"key": "shelf", "label": "Paling sering di shelf"}],
 "missing_options": [{"key": "nutrition", "label": "Gizi"}, {"key": "nova", "label": "NOVA"}],
 "stats": {"incomplete_products": 1, "submitted_last_7_days": 0, "approved": 0, "shelf_average": 0.1},
 "results": [
  {"id": 107, "product_name": "BLUE BAND CAKE & COOKIE", "brand": "", "quantity": "", "image_url": "",
   "missing": [
     {"key": "nutrition", "label": "Gizi", "correctable": true, "fields": ["proteins_100g", "fiber_100g", "sodium_100g"]},
     {"key": "nova", "label": "NOVA", "correctable": true, "fields": ["nova_group"]},
     {"key": "packaging", "label": "Kemasan", "correctable": false, "fields": []}],
   "missing_count": 5, "shelf_count": 5, "status": "needs_contribution", "status_label": "Perlu kontribusi"}]}
''';

// Bentuk balasan 201 POST mine/: serat 7,5 g dan natrium 500 mg (disimpan 0,5 g).
const correctionJson = r'''
{"id": 12, "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g",
  "image_url": "", "is_active": true},
 "status": "pending", "status_label": "Menunggu", "is_withdrawable": true, "created_at": "2026-11-24T12:00:00.000000Z",
 "items": [
  {"id": 31, "field_name": "fiber_100g", "label": "Serat (g/100 g)", "old_value": null, "proposed_value": 7.5,
   "old_display": null, "proposed_display": "7,5", "status": "pending", "status_label": "Menunggu", "review_note": ""},
  {"id": 32, "field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "old_value": 0.78, "proposed_value": 0.5,
   "old_display": "780", "proposed_display": "500", "status": "pending", "status_label": "Menunggu", "review_note": ""}]}
''';

String formBody(List<String> focus) => jsonEncode({
  'product': {
    'id': 1,
    'product_name': 'Sarimi Isi 2 Goreng',
    'brand': 'Sarimi',
    'quantity': '88 g',
    'image_url': '',
    'is_active': true,
  },
  'focus': focus,
  'correctable_fields': jsonDecode(fieldsJson),
});

/// Seperti server: focus hanya berisi nama field yang dikenal, urutannya mengikuti ?field=.
http.Response formReply(http.Request request) {
  final asked = request.url.queryParametersAll['field'] ?? const <String>[];
  return jsonResponse(
    formBody([
      for (final name in asked)
        if (fieldNames.contains(name)) name,
    ]),
    200,
  );
}

/// GET form dan POST mine/ yang berhasil.
http.Response serverReply(http.Request request) => request.method == 'POST'
    ? jsonResponse(correctionJson, 201)
    : formReply(request);

/// GET me/ menjawab sudah masuk (gerbang login antrean); permintaan lain diteruskan ke reply.
http.Response Function(http.Request) signedIn(
  http.Response Function(http.Request) reply,
) =>
    (request) => request.url.path.endsWith('/me/')
    ? jsonResponse('{"logged_in": true, "is_staff": false}', 200)
    : reply(request);

List<http.Request> posts(List<http.Request> log) => [
  for (final request in log)
    if (request.method == 'POST') request,
];

FilledButton submitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpForm(
  WidgetTester tester, {
  List<String> focus = const [],
}) async {
  useTallView(tester);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: FakeRequest(),
      child: MaterialApp(home: CorrectionFormPage(productId: 1, focus: focus)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('checkProposedValue uses the server messages', () {
    final form = CorrectionFormData.fromJson(
      jsonDecode(formBody(const [])) as Map<String, dynamic>,
    );
    final nova = form.field('nova_group')!;
    final fiber = form.field('fiber_100g')!;
    final brand = form.field('brand')!;
    expect(checkProposedValue(fiber, '  '), requiredMessage);
    expect([
      for (final text in ['7,5', '7.5', ',5', '0', '-0'])
        checkProposedValue(fiber, text),
    ], everyElement(isNull));
    expect(checkProposedValue(fiber, 'abc'), 'Masukkan angka, misalnya 7,5.');
    expect(
      checkProposedValue(fiber, '1.234,5'),
      startsWith('Tulis angka tanpa pemisah ribuan'),
    );
    expect(checkProposedValue(fiber, '-1'), 'Nilai tidak boleh negatif.');
    expect(checkProposedValue(nova, '3'), isNull);
    for (final text in ['0', '5', '2,5', 'abc', '-1']) {
      expect(
        checkProposedValue(nova, text),
        'Grup NOVA harus bilangan bulat 1 sampai 4.',
      );
    }
    expect(checkProposedValue(brand, 'Blue Band'), isNull);
  });

  testWidgets('shows the product and one row per known prefilled field', (
    tester,
  ) async {
    final log = await withMockServer(formReply, () async {
      await pumpForm(tester, focus: ['fiber_100g', 'sodium_100g', 'code']);
      expect(find.text('Antrean Data › Lengkapi Data'), findsOneWidget);
      expect(find.text('Lengkapi Data'), findsOneWidget);
      expect(find.text('Ajukan koreksi data produk.'), findsOneWidget);
      expect(find.text('Sarimi Isi 2 Goreng · Sarimi · 88 g'), findsOneWidget);
      expect(find.text('Nilai saat ini'), findsNWidgets(2));
      expect(find.text('Tidak diketahui'), findsOneWidget);
      expect(find.text('780'), findsOneWidget);
      expect(
        find.text(
          'Angka dalam mg per 100 g, tanpa pemisah ribuan. Contoh: 780.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Usulan belum disetujui', findRichText: true),
        findsOneWidget,
      );
    });
    expect(
      log.single.url.toString(),
      '$base/products/1/form/?field=fiber_100g&field=sodium_100g&field=code',
    );
  });

  testWidgets('starts with one empty row without focus', (tester) async {
    await withMockServer(formReply, () async {
      await pumpForm(tester);
      expect(find.text('Nilai saat ini'), findsOneWidget);
      expect(find.text('Pilih field…'), findsOneWidget);
      expect(find.text('Pilih field dulu'), findsOneWidget);
      expect(find.byTooltip('Hapus baris ini'), findsNothing);
    });
  });

  testWidgets(
    'adds and removes rows, and a used field cannot be picked again',
    (tester) async {
      await withMockServer(formReply, () async {
        await pumpForm(tester, focus: ['fiber_100g']);
        await tester.tap(find.text('+ Tambah field lain'));
        await tester.pump();
        expect(find.text('Nilai saat ini'), findsNWidgets(2));
        expect(find.byTooltip('Hapus baris ini'), findsNWidgets(2));
        final fiberItems = tester
            .widgetList<DropdownMenuItem<String>>(
              find.byType(DropdownMenuItem<String>, skipOffstage: false),
            )
            .where((item) => item.value == 'fiber_100g');
        expect(
          [for (final item in fiberItems) item.enabled],
          [true, false],
        ); // baris 1 memakainya, baris 2 tidak boleh

        await tester.tap(find.byTooltip('Hapus baris ini').last);
        await tester.pump();
        await tester.pump();
        expect(find.text('Nilai saat ini'), findsOneWidget);
        expect(find.byTooltip('Hapus baris ini'), findsNothing);
      });
    },
  );

  testWidgets('checks the inputs before sending and skips empty rows', (
    tester,
  ) async {
    final log = await withMockServer(serverReply, () async {
      await pumpForm(tester, focus: ['nova_group', 'fiber_100g']);
      final inputs = find.byType(TextFormField);

      await tester.tap(find.text('Ajukan Koreksi'));
      await tester.pump();
      expect(find.text(requiredMessage), findsNWidgets(2));
      expect(find.text(noneFilledMessage), findsOneWidget);

      await tester.enterText(inputs.at(0), '5');
      await tester.enterText(inputs.at(1), 'abc');
      await tester.tap(find.text('Ajukan Koreksi'));
      await tester.pump();
      expect(
        find.text('Grup NOVA harus bilangan bulat 1 sampai 4.'),
        findsOneWidget,
      );
      expect(find.text('Masukkan angka, misalnya 7,5.'), findsOneWidget);
      expect(find.text(checkInputsMessage), findsOneWidget);
      expect(find.text(requiredMessage), findsNothing);

      await tester.enterText(inputs.at(0), '3');
      await tester.enterText(inputs.at(1), ''); // baris kosong tidak dikirim
      await tester.tap(find.text('Ajukan Koreksi'));
      await tester.pumpAndSettle();
      expect(find.byType(CorrectionDetailPage), findsOneWidget);
    });
    // single: percobaan yang salah tidak pernah dikirim.
    expect(jsonDecode(posts(log).single.body)['items'], [
      {'field_name': 'nova_group', 'proposed_value': '3'},
    ]);
  });

  testWidgets('Coba lagi loads the form again after an error', (tester) async {
    var calls = 0;
    final log = await withMockServer(
      (request) => ++calls == 1 ? htmlResponse(500) : formReply(request),
      () async {
        await pumpForm(tester);
        expect(
          find.text('Server sedang bermasalah. Coba lagi nanti.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();
        expect(find.text('Lengkapi Data'), findsOneWidget);
      },
    );
    expect(log, hasLength(2));
  });

  testWidgets(
    'Lengkapi Data on the queue opens the form with the correctable missing fields',
    (tester) async {
      final log = await withMockServer(signedIn(formReply), () async {
        useTallView(tester);
        final request = FakeRequest(() => jsonDecode(queueJson))
          ..loggedIn = true;
        await tester.pumpWidget(
          Provider<CookieRequest>.value(
            value: request,
            child: const MaterialApp(home: DataCorrectionPage()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lengkapi Data'));
        await tester.pumpAndSettle();
        expect(find.byType(CorrectionFormPage), findsOneWidget);
        expect(
          find.text('Nilai saat ini'),
          findsNWidgets(3),
        ); // proteins_100g tidak ada di form palsu ini
      });
      expect(
        [for (final request in log) request.url.toString()],
        [
          '$base/me/',
          '$base/products/107/form/?field=proteins_100g&field=fiber_100g&field=sodium_100g&field=nova_group',
        ],
      );
    },
  );

  testWidgets('sends the values in display units and opens the success page', (
    tester,
  ) async {
    final log = await withMockServer(serverReply, () async {
      await pumpForm(tester, focus: ['fiber_100g', 'sodium_100g']);
      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.at(0), '7,5');
      await tester.enterText(inputs.at(1), '500');
      await tester.tap(find.text('Ajukan Koreksi'));
      await tester.pumpAndSettle();

      expect(find.byType(CorrectionFormPage), findsNothing);
      expect(
        find.text('Pengajuan berhasil dikirim'),
        findsNWidgets(2),
      ); // judul dan toast
      expect(find.text('Pengajuan Saya › Pengajuan #12'), findsOneWidget);
      expect(
        find.text('Pengajuan #12 · diajukan 24 November 2026'),
        findsOneWidget,
      );
      expect(find.text('Sarimi Isi 2 Goreng'), findsOneWidget);
      expect(find.text('Menunggu'), findsNWidgets(3)); // pengajuan dan dua item
      expect(find.text('Nilai saat ini'), findsNWidgets(2));
      expect(find.text('Tidak diketahui'), findsOneWidget);
      expect(find.text('780'), findsOneWidget);
      expect(
        find.textContaining('· belum disetujui', findRichText: true),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('Usulan belum disetujui', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Kembali ke Antrean Data'), findsOneWidget);
    });
    final post = posts(log).single;
    expect(
      [post.url.toString(), post.headers['X-CSRFToken']],
      ['$base/mine/', 't'],
    );
    expect(jsonDecode(post.body), {
      'product': 1,
      'items': [
        {'field_name': 'fiber_100g', 'proposed_value': '7,5'},
        {'field_name': 'sodium_100g', 'proposed_value': '500'},
      ],
    });
  });

  testWidgets('shows server field errors on the matching row', (tester) async {
    const body =
        '{"detail": "Periksa kembali isian koreksi.", "code": "validation_error", "fields": '
        '{"sodium_100g": ["Usulan sama dengan nilai saat ini."], "code": ["Field ini tidak boleh dikoreksi."]}}';
    final log = await withMockServer(
      (request) => request.method == 'POST'
          ? jsonResponse(body, 400)
          : formReply(request),
      () async {
        await pumpForm(tester, focus: ['fiber_100g', 'sodium_100g']);
        final inputs = find.byType(TextFormField);
        await tester.enterText(inputs.at(0), '7,5');
        await tester.enterText(inputs.at(1), '780');
        await tester.tap(find.text('Ajukan Koreksi'));
        await tester.pumpAndSettle();

        const sameValue = 'Usulan sama dengan nilai saat ini.';
        final sodiumRow = find.byKey(const ValueKey('correction-row-1'));
        expect(
          find.descendant(of: sodiumRow, matching: find.text(sameValue)),
          findsOneWidget,
        );
        expect(find.text(sameValue), findsOneWidget); // bukan di baris serat
        expect(
          find.text(
            'Periksa kembali isian koreksi.\nField ini tidak boleh dikoreksi.',
          ),
          findsOneWidget,
        );
        expect(find.byType(CorrectionFormPage), findsOneWidget);
        expect(submitButton(tester).onPressed, isNotNull);
      },
    );
    expect(posts(log), hasLength(1));
  });

  testWidgets('disables the button while the request is running', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final sent = <http.Request>[];
    await http.runWithClient(
      () async {
        await pumpForm(tester, focus: ['fiber_100g']);
        await tester.enterText(find.byType(TextFormField), '7,5');
        await tester.tap(find.text('Ajukan Koreksi'));
        await tester.pump();
        expect(submitButton(tester).onPressed, isNull);
        expect(find.text('Mengirim…'), findsOneWidget);

        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(sent, hasLength(1));

        pending.complete(jsonResponse(correctionJson, 201));
        await tester.pumpAndSettle();
        expect(find.byType(CorrectionDetailPage), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.method != 'POST') return formReply(request);
        sent.add(request);
        return pending.future;
      }),
    );
    expect(sent, hasLength(1));
  });

  testWidgets('shows the right message for 403, 409 and network errors', (
    tester,
  ) async {
    const inactive = 'Produk ini tidak aktif sehingga tidak bisa dikoreksi.';
    var attempt = 0;
    final log = await withMockServer(
      (request) {
        if (request.method != 'POST') {
          return formReply(request);
        }
        attempt++;
        if (attempt == 1) {
          return jsonResponse(
            '{"detail": "Silakan masuk terlebih dahulu.", "code": "authentication_required"}',
            403,
          );
        }
        if (attempt == 2) {
          return jsonResponse(
            '{"detail": "$inactive", "code": "product_inactive"}',
            409,
          );
        }
        if (attempt == 3) {
          throw http.ClientException('Connection refused');
        }
        return jsonResponse(correctionJson, 201);
      },
      () async {
        await pumpForm(tester, focus: ['fiber_100g']);
        await tester.enterText(find.byType(TextFormField), '7,5');
        await tester.tap(find.text('Ajukan Koreksi'));
        await tester.pumpAndSettle();
        expect(find.text(sessionEndedMessage), findsOneWidget);

        await tester.tap(find.text('Ajukan Koreksi'));
        await tester.pumpAndSettle();
        expect(find.text(sessionEndedMessage), findsNothing);
        expect(find.text(inactive), findsOneWidget);
        expect(find.widgetWithText(SnackBarAction, 'Coba lagi'), findsNothing);

        await tester.tap(find.text('Ajukan Koreksi'));
        await tester.pumpAndSettle();
        expect(find.text(inactive), findsNothing);
        expect(find.text(ApiError.defaultMessage(0)), findsOneWidget);

        await tester.tap(find.widgetWithText(SnackBarAction, 'Coba lagi'));
        await tester.pumpAndSettle();
        expect(find.byType(CorrectionDetailPage), findsOneWidget);
      },
    );
    expect(posts(log), hasLength(4));
  });

  testWidgets('the detail page loads by id and retries with Coba lagi', (
    tester,
  ) async {
    var calls = 0;
    final log = await withMockServer(
      (request) => ++calls == 1
          ? jsonResponse(
              '{"detail": "Pengajuan tidak ditemukan.", "code": "correction_not_found"}',
              404,
            )
          : jsonResponse(correctionJson, 200),
      () async {
        useTallView(tester);
        await tester.pumpWidget(
          Provider<CookieRequest>.value(
            value: FakeRequest(),
            child: const MaterialApp(
              home: CorrectionDetailPage(correctionId: 12),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pengajuan tidak ditemukan.'), findsOneWidget);

        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();
        expect(find.text('Detail pengajuan'), findsOneWidget);
        expect(find.text('Nilai saat diajukan'), findsNWidgets(2));
        expect(find.text('Pengajuan berhasil dikirim'), findsNothing);
        expect(find.text('Kembali ke Antrean Data'), findsNothing);
      },
    );
    expect(
      [for (final request in log) request.url.toString()],
      ['$base/mine/12/', '$base/mine/12/'],
    );
  });
}
