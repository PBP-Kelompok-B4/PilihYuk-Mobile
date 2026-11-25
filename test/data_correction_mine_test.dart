import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';
import 'package:pilihyuk_mobile/screens/data_correction/data_correction_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/my_corrections_page.dart';

import 'data_correction_fakes.dart';

const base = '$baseUrl/api/v1/corrections';

// Bentuk GET mine/: halaman 1 dari 2, terbaru dulu. #12 menunggu, #9 sebagian disetujui dengan catatan kurator.
const pageOneJson = r'''
{"count": 11, "page": 1, "page_size": 10, "num_pages": 2, "next_page": 2, "previous_page": null,
 "results": [
  {"id": 12, "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g",
    "image_url": "", "is_active": true},
   "status": "pending", "status_label": "Menunggu", "is_withdrawable": true, "created_at": "2026-11-24T12:00:00Z",
   "items": [
    {"id": 31, "field_name": "fiber_100g", "label": "Serat (g/100 g)", "old_value": null, "proposed_value": 7.5,
     "old_display": null, "proposed_display": "7,5", "status": "pending", "status_label": "Menunggu", "review_note": ""}]},
  {"id": 9, "product": {"id": 107, "product_name": "BLUE BAND CAKE & COOKIE", "brand": "", "quantity": "",
    "image_url": "", "is_active": true},
   "status": "partial", "status_label": "Sebagian disetujui", "is_withdrawable": false,
   "created_at": "2026-11-20T12:00:00Z",
   "items": [
    {"id": 21, "field_name": "brand", "label": "Merek", "old_value": null, "proposed_value": "Blue Band",
     "old_display": null, "proposed_display": "Blue Band", "status": "approved", "status_label": "Disetujui",
     "review_note": ""},
    {"id": 22, "field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "old_value": 0.78, "proposed_value": 0.5,
     "old_display": "780", "proposed_display": "500", "status": "rejected", "status_label": "Ditolak",
     "review_note": "Tidak sesuai label."}]}]}
''';

const pageTwoJson = r'''
{"count": 11, "page": 2, "page_size": 10, "num_pages": 2, "next_page": null, "previous_page": 1,
 "results": [
  {"id": 2, "product": {"id": 5, "product_name": "Teh Botol Sosro", "brand": "Sosro", "quantity": "450 ml",
    "image_url": "", "is_active": true},
   "status": "rejected", "status_label": "Ditolak", "is_withdrawable": false, "created_at": "2026-11-02T12:00:00Z",
   "items": [
    {"id": 3, "field_name": "nova_group", "label": "Grup NOVA", "old_value": null, "proposed_value": 2,
     "old_display": null, "proposed_display": "2", "status": "rejected", "status_label": "Ditolak",
     "review_note": "Minuman berpemanis biasanya NOVA 4."}]}]}
''';

const emptyJson =
    '{"count": 0, "page": 1, "page_size": 10, "num_pages": 1, "next_page": null, "previous_page": null, "results": []}';

// Antrean kosong secukupnya untuk membangun DataCorrectionPage.
const emptyQueueJson = r'''
{"count": 0, "page": 1, "page_size": 20, "num_pages": 1, "next_page": null, "previous_page": null,
 "sort": "shelf", "missing": null, "shelf_available": true, "sort_options": [], "missing_options": [],
 "stats": {"incomplete_products": 0, "submitted_last_7_days": 0, "approved": 0, "shelf_average": 0},
 "results": []}
''';

const notWithdrawable =
    'Pengajuan ini sudah mulai ditinjau sehingga tidak bisa ditarik.';
const withdrawText =
    'Pengajuan untuk Sarimi Isi 2 Goreng akan dihapus beserta semua usulannya dan tidak bisa dikembalikan.';

/// ?page=2 -> halaman 2, selain itu halaman 1.
http.Response pagedReply(http.Request request) => jsonResponse(
  request.url.queryParameters['page'] == '2' ? pageTwoJson : pageOneJson,
  200,
);

/// Halaman 1 setelah #12 ditarik: tinggal #9, satu halaman.
String withoutFirst() {
  final json = jsonDecode(pageOneJson) as Map<String, dynamic>;
  (json['results'] as List).removeAt(0);
  json
    ..['count'] = 10
    ..['num_pages'] = 1
    ..['next_page'] = null;
  return jsonEncode(json);
}

/// Halaman 1 setelah kurator menyetujui #12: tidak bisa ditarik lagi.
String reviewedFirst() {
  final json = jsonDecode(pageOneJson) as Map<String, dynamic>;
  json['results'][0]
    ..['status'] = 'approved'
    ..['status_label'] = 'Disetujui'
    ..['is_withdrawable'] = false;
  json['results'][0]['items'][0]
    ..['status'] = 'approved'
    ..['status_label'] = 'Disetujui';
  return jsonEncode(json);
}

/// Server palsu: DELETE mine/12/ -> 204, lalu GET mine/ tanpa #12.
http.Response Function(http.Request) withdrawServer() {
  var withdrawn = false;
  return (request) {
    if (request.method == 'DELETE') {
      withdrawn = true;
      return http.Response('', 204);
    }
    return jsonResponse(withdrawn ? withoutFirst() : pageOneJson, 200);
  };
}

List<String> requestLines(List<http.Request> log) => [
  for (final request in log) '${request.method} ${request.url}',
];

Finder inCard(int id, String text) => find.descendant(
  of: find.byKey(ValueKey('correction-$id')),
  matching: find.text(text),
);

void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpMine(WidgetTester tester) async {
  useTallView(tester);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: FakeRequest(),
      child: const MaterialApp(home: MyCorrectionsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows each correction with its status, items and curator notes',
    (tester) async {
      final log = await withMockServer(pagedReply, () async {
        await pumpMine(tester);
        expect(find.widgetWithText(AppBar, 'Pengajuan Saya'), findsOneWidget);
        expect(
          find.text(
            'Status koreksi yang kamu ajukan. Pengajuan yang belum ditinjau sama sekali masih bisa ditarik.',
          ),
          findsOneWidget,
        );
        expect(find.text('Sarimi Isi 2 Goreng'), findsOneWidget);
        expect(
          find.text('Pengajuan #12 · diajukan 24 November 2026'),
          findsOneWidget,
        );
        expect(find.text('BLUE BAND CAKE & COOKIE'), findsOneWidget);
        expect(
          find.text('Pengajuan #9 · diajukan 20 November 2026'),
          findsOneWidget,
        );
        expect(
          find.text('Menunggu'),
          findsNWidgets(2),
        ); // pengajuan #12 dan itemnya
        expect(find.text('Sebagian disetujui'), findsOneWidget);
        expect(find.text('Disetujui'), findsOneWidget);
        expect(find.text('Ditolak'), findsOneWidget);
        expect(
          find.textContaining('Tidak diketahui → 7,5', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('780 → 500', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.text('Catatan kurator: Tidak sesuai label.'),
          findsOneWidget,
        );
        expect(find.text('Lihat detail'), findsNWidgets(2));
        expect(find.text('Halaman 1 dari 2'), findsOneWidget);
      });
      expect(log.single.url.toString(), '$base/mine/');
    },
  );

  testWidgets('Berikutnya asks for ?page=2 and Sebelumnya goes back', (
    tester,
  ) async {
    final log = await withMockServer(pagedReply, () async {
      await pumpMine(tester);
      await tester.tap(find.text('Berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('Teh Botol Sosro'), findsOneWidget);
      expect(find.text('Sarimi Isi 2 Goreng'), findsNothing);
      expect(find.text('Halaman 2 dari 2'), findsOneWidget);

      await tester.tap(find.text('Sebelumnya'));
      await tester.pumpAndSettle();
      expect(find.text('Sarimi Isi 2 Goreng'), findsOneWidget);
    });
    expect(
      [for (final request in log) request.url.toString()],
      ['$base/mine/', '$base/mine/?page=2', '$base/mine/'],
    );
  });

  testWidgets('shows the empty state and Buka Antrean Data goes back', (
    tester,
  ) async {
    await withMockServer((_) => jsonResponse(emptyJson, 200), () async {
      useTallView(tester);
      await tester.pumpWidget(
        Provider<CookieRequest>.value(
          value: FakeRequest(),
          child: const MaterialApp(
            home: Scaffold(body: Text('Halaman sebelumnya')),
          ),
        ),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(builder: (_) => const MyCorrectionsPage()),
          );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada pengajuan.'), findsOneWidget);
      expect(
        find.text(
          'Bantu lengkapi data produk yang masih kosong dari Antrean Data.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Halaman 1'), findsNothing);

      await tester.tap(find.text('Buka Antrean Data'));
      await tester.pumpAndSettle();
      expect(find.byType(MyCorrectionsPage), findsNothing);
      expect(find.text('Halaman sebelumnya'), findsOneWidget);
    });
  });

  testWidgets('shows the error and Coba lagi loads again', (tester) async {
    var calls = 0;
    final log = await withMockServer(
      (request) => ++calls == 1 ? htmlResponse(500) : pagedReply(request),
      () async {
        await pumpMine(tester);
        expect(
          find.text('Server sedang bermasalah. Coba lagi nanti.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();
        expect(find.text('Sarimi Isi 2 Goreng'), findsOneWidget);
      },
    );
    expect(log, hasLength(2));
  });

  testWidgets('Lihat detail opens the detail page with the list data', (
    tester,
  ) async {
    final log = await withMockServer(pagedReply, () async {
      await pumpMine(tester);
      await tester.tap(find.text('Lihat detail').last);
      await tester.pumpAndSettle();
      expect(find.byType(CorrectionDetailPage), findsOneWidget);
      expect(find.text('Detail pengajuan'), findsOneWidget);
      expect(find.text('Pengajuan Saya › Pengajuan #9'), findsOneWidget);
      expect(find.text('Nilai saat diajukan'), findsNWidgets(2));
      expect(find.text('Catatan kurator: Tidak sesuai label.'), findsOneWidget);
    });
    expect(log, hasLength(1)); // detail tidak memanggil GET mine/9/
  });

  testWidgets('the Pengajuan Saya action only shows when logged in', (
    tester,
  ) async {
    final log = await withMockServer(pagedReply, () async {
      useTallView(tester);
      final guest = FakeRequest(() => jsonDecode(emptyQueueJson));
      await tester.pumpWidget(
        Provider<CookieRequest>.value(
          value: guest,
          child: const MaterialApp(home: DataCorrectionPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pengajuan Saya'), findsNothing);

      final member = FakeRequest(() => jsonDecode(emptyQueueJson))
        ..loggedIn = true;
      await tester.pumpWidget(
        Provider<CookieRequest>.value(
          value: member,
          child: const MaterialApp(home: DataCorrectionPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pengajuan Saya'));
      await tester.pumpAndSettle();
      expect(find.byType(MyCorrectionsPage), findsOneWidget);
      expect(find.text('Sarimi Isi 2 Goreng'), findsOneWidget);
    });
    expect(log.single.url.toString(), '$base/mine/');
  });

  testWidgets('Tarik pengajuan only shows for withdrawable corrections', (
    tester,
  ) async {
    await withMockServer(pagedReply, () async {
      await pumpMine(tester);
      expect(find.text('Tarik pengajuan'), findsOneWidget);
      expect(inCard(12, 'Tarik pengajuan'), findsOneWidget);
      expect(inCard(9, 'Tarik pengajuan'), findsNothing);
    });
  });

  testWidgets('Batal closes the sheet without sending DELETE', (tester) async {
    final log = await withMockServer(pagedReply, () async {
      await pumpMine(tester);
      await tester.tap(find.text('Tarik pengajuan'));
      await tester.pumpAndSettle();
      expect(find.text('Tarik pengajuan ini?'), findsOneWidget);
      expect(find.text(withdrawText), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Tarik pengajuan ini?'), findsNothing);
      expect(find.byKey(const ValueKey('correction-12')), findsOneWidget);
    });
    expect(requestLines(log), ['GET $base/mine/']);
  });

  testWidgets('Tarik Pengajuan sends DELETE and the card disappears', (
    tester,
  ) async {
    final log = await withMockServer(withdrawServer(), () async {
      await pumpMine(tester);
      await tester.tap(find.text('Tarik pengajuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarik Pengajuan'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('correction-12')), findsNothing);
      expect(find.byKey(const ValueKey('correction-9')), findsOneWidget);
      expect(find.text(withdrawnMessage), findsOneWidget);
    });
    expect(requestLines(log), [
      'GET $base/mine/',
      'DELETE $base/mine/12/',
      'GET $base/mine/',
    ]);
    expect(log[1].headers['X-CSRFToken'], 't');
  });

  testWidgets('409 shows the server message and reloads the status', (
    tester,
  ) async {
    var refused = false;
    final log = await withMockServer(
      (request) {
        if (request.method == 'DELETE') {
          refused = true;
          return jsonResponse(
            '{"detail": "$notWithdrawable", "code": "not_withdrawable"}',
            409,
          );
        }
        return jsonResponse(refused ? reviewedFirst() : pageOneJson, 200);
      },
      () async {
        await pumpMine(tester);
        await tester.tap(find.text('Tarik pengajuan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tarik Pengajuan'));
        await tester.pumpAndSettle();

        expect(find.text(notWithdrawable), findsOneWidget);
        expect(find.text('Tarik pengajuan'), findsNothing);
        expect(inCard(12, 'Menunggu'), findsNothing);
        expect(
          inCard(12, 'Disetujui'),
          findsNWidgets(2),
        ); // pengajuan dan itemnya
      },
    );
    expect(requestLines(log), [
      'GET $base/mine/',
      'DELETE $base/mine/12/',
      'GET $base/mine/',
    ]);
  });

  testWidgets('Tarik from the detail page returns to a reloaded list', (
    tester,
  ) async {
    final log = await withMockServer(withdrawServer(), () async {
      await pumpMine(tester);
      await tester.tap(find.text('Lihat detail').first);
      await tester.pumpAndSettle();
      expect(find.text('Detail pengajuan'), findsOneWidget);

      await tester.tap(find.text('Tarik pengajuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarik Pengajuan'));
      await tester.pumpAndSettle();

      expect(find.byType(CorrectionDetailPage), findsNothing);
      expect(find.byKey(const ValueKey('correction-12')), findsNothing);
      expect(find.text(withdrawnMessage), findsOneWidget);
    });
    expect(requestLines(log), [
      'GET $base/mine/',
      'DELETE $base/mine/12/',
      'GET $base/mine/',
    ]);
  });
}
