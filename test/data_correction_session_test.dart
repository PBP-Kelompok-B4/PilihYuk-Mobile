import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_form_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';
import 'package:pilihyuk_mobile/screens/data_correction/data_correction_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/module_navigation.dart';
import 'package:pilihyuk_mobile/screens/data_correction/my_corrections_page.dart';
import 'package:pilihyuk_mobile/screens/login.dart';

import 'data_correction_fakes.dart';

const member = '{"logged_in": true, "is_staff": false}';
const sessionEnded =
    '{"detail": "Silakan masuk terlebih dahulu.", "code": "authentication_required"}';

// Satu produk yang hanya kekurangan serat.
const queueJson = r'''
{"count": 1, "page": 1, "page_size": 20, "num_pages": 1, "next_page": null, "previous_page": null,
 "sort": "shelf", "missing": null, "shelf_available": true,
 "sort_options": [{"key": "shelf", "label": "Paling sering di shelf"}], "missing_options": [],
 "stats": {"incomplete_products": 1, "submitted_last_7_days": 0, "approved": 0, "shelf_average": 0.1},
 "results": [
  {"id": 107, "product_name": "BLUE BAND CAKE & COOKIE", "brand": "", "quantity": "", "image_url": "",
   "missing": [{"key": "nutrition", "label": "Gizi", "correctable": true, "fields": ["fiber_100g"]}],
   "missing_count": 1, "shelf_count": 5, "status": "needs_contribution", "status_label": "Perlu kontribusi"}]}
''';

const productJson =
    '{"id": 107, "product_name": "BLUE BAND CAKE & COOKIE", "brand": "", "quantity": "", "image_url": "", '
    '"is_active": true}';

const formJson =
    '{"product": $productJson, "focus": ["fiber_100g"], "correctable_fields": [{"field_name": "fiber_100g", '
    '"label": "Serat (g/100 g)", "group": "Gizi per 100 g", "type": "number", "current_value": null, '
    '"current_display": null, "display_factor": 1, "help_text": "Angka dalam g per 100 g."}]}';

const correctionJson =
    '{"id": 12, "product": $productJson, "status": "pending", "status_label": "Menunggu", "is_withdrawable": true, '
    '"created_at": "2026-11-24T12:00:00Z", "items": [{"id": 31, "field_name": "fiber_100g", '
    '"label": "Serat (g/100 g)", "old_value": null, "proposed_value": 7.5, "old_display": null, '
    '"proposed_display": "7,5", "status": "pending", "status_label": "Menunggu", "review_note": ""}]}';

String mineJson(List<String> results) =>
    '{"count": ${results.length}, "page": 1, "page_size": 10, "num_pages": 1, "next_page": null, '
    '"previous_page": null, "results": [${results.join(', ')}]}';

Map<String, dynamic> queueReply() =>
    jsonDecode(queueJson) as Map<String, dynamic>;

String route(http.Request request) =>
    '${request.method} ${request.url.path.split('/api/v1/corrections/').last}';

List<String> routes(List<http.Request> log) => [
  for (final request in log) route(request),
];

Future<void> pumpQueue(WidgetTester tester, FakeRequest request) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: request,
      child: const MaterialApp(home: DataCorrectionPage()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Selama sheet terbuka, halaman di bawahnya masih memutar indikator, jadi pumpAndSettle tidak pernah selesai.
/// Beberapa frame berjarak dipakai, karena sheet bisa baru muncul di tengah pump dan animasinya perlu frame lagi.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Meniru LoginPage setelah berhasil: sesi terpasang, lalu pushReplacement ke Katalog.
void logIn(WidgetTester tester, FakeRequest request) {
  request.loggedIn = true;
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Katalog')),
        ),
      );
}

void main() {
  testWidgets(
    'a 403 inside the module shows the session sheet, and logging in again retries once',
    (tester) async {
      final request = FakeRequest(queueReply)..loggedIn = true;
      var mineCalls = 0;
      final log = await withMockServer(
        (r) => switch (route(r)) {
          'GET me/' => jsonResponse(member, 200),
          'GET mine/' =>
            ++mineCalls == 1
                ? jsonResponse(sessionEnded, 403)
                : jsonResponse(mineJson([]), 200),
          _ => jsonResponse('{}', 404),
        },
        () async {
          await pumpQueue(tester, request);
          await tester.tap(find.byTooltip('Pengajuan Saya'));
          await settle(tester);
          expect(find.text(loginRequiredTitle), findsOneWidget);
          expect(find.text(sessionEndedMessage), findsOneWidget);
          expect([request.logoutCalls, request.loggedIn], [1, false]);

          await tester.tap(find.text('Masuk'));
          await settle(tester);
          expect(find.byType(LoginPage), findsOneWidget);

          logIn(tester, request);
          await tester.pumpAndSettle();
          expect(find.text('Katalog'), findsNothing);
          expect(
            find.byType(MyCorrectionsPage),
            findsOneWidget,
          ); // kembali ke halaman yang tadi, bukan antrean
          expect(find.text('Belum ada pengajuan.'), findsOneWidget);
        },
      );
      expect(routes(log), ['GET me/', 'GET mine/', 'GET me/', 'GET mine/']);
    },
  );

  testWidgets(
    'closing the session sheet keeps the form, its value and the session message',
    (tester) async {
      final request = FakeRequest(queueReply)..loggedIn = true;
      final log = await withMockServer(
        (r) => switch (route(r)) {
          'GET me/' => jsonResponse(member, 200),
          'GET products/107/form/' => jsonResponse(formJson, 200),
          _ => jsonResponse(sessionEnded, 403),
        },
        () async {
          await pumpQueue(tester, request);
          await tester.tap(find.text('Lengkapi Data'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), '7,5');
          await tester.tap(find.text('Ajukan Koreksi'));
          await settle(tester);
          expect(find.text(loginRequiredTitle), findsOneWidget);

          await tester.tap(find.byTooltip('Tutup'));
          await tester.pumpAndSettle();
          expect(find.text(loginRequiredTitle), findsNothing);
          expect(find.byType(CorrectionFormPage), findsOneWidget);
          expect(find.text('7,5'), findsOneWidget);
          expect(
            find.text(sessionEndedMessage),
            findsOneWidget,
          ); // kotak galat form
        },
      );
      expect(routes(log), [
        'GET me/',
        'GET products/107/form/',
        'POST mine/',
        'GET me/',
      ]);
      expect(request.logoutCalls, 1);
    },
  );

  testWidgets(
    'withdrawing in Pengajuan Saya reloads the queue once after going back',
    (tester) async {
      final request = FakeRequest(queueReply);
      var withdrawn = false;
      final log = await withMockServer(
        (r) {
          if (route(r) == 'DELETE mine/12/') {
            withdrawn = true;
            return http.Response('', 204);
          }
          return route(r) == 'GET me/'
              ? jsonResponse(member, 200)
              : jsonResponse(mineJson(withdrawn ? [] : [correctionJson]), 200);
        },
        () async {
          await pumpQueue(tester, request);
          await tester.tap(find.byTooltip('Pengajuan Saya'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Tarik pengajuan'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Tarik Pengajuan'));
          await tester.pumpAndSettle();
          expect(find.text('Belum ada pengajuan.'), findsOneWidget);
          expect(
            request.urls,
            hasLength(1),
          ); // antrean baru dimuat ulang saat pengguna kembali

          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(request.urls, hasLength(2));

          await tester.tap(find.byTooltip('Pengajuan Saya'));
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(
            request.urls,
            hasLength(2),
          ); // tanpa perubahan: tidak dimuat ulang
        },
      );
      expect(routes(log), [
        'GET me/',
        'GET mine/',
        'DELETE mine/12/',
        'GET mine/',
        'GET mine/',
      ]);
    },
  );
}
