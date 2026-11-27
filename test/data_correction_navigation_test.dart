import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_form_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/data_correction_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/moderation_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/module_navigation.dart';
import 'package:pilihyuk_mobile/screens/data_correction/my_corrections_page.dart';
import 'package:pilihyuk_mobile/screens/login.dart';
import 'package:pilihyuk_mobile/screens/register.dart';

import 'data_correction_fakes.dart';

const guest = {'logged_in': false, 'is_staff': false};
const member = {'logged_in': true, 'is_staff': false};
const curator = {'logged_in': true, 'is_staff': true};

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

const emptyMineJson =
    '{"count": 0, "page": 1, "page_size": 10, "num_pages": 1, "next_page": null, "previous_page": null, "results": []}';

const emptyModerationJson =
    '{"count": 0, "page": 1, "page_size": 20, "num_pages": 1, "next_page": null, "previous_page": null, '
    '"tab": "antrean", "field": null, "status": null, "tab_options": [{"key": "antrean", "label": "Antrean koreksi"}], '
    '"field_options": [], "status_options": [], "stats": {"pending": 0, "approved": 0, "rejected": 0}, "results": []}';

Map<String, dynamic> queueReply() =>
    jsonDecode(queueJson) as Map<String, dynamic>;

/// "GET me/", "POST mine/", dst. (tanpa query).
String route(http.Request request) =>
    '${request.method} ${request.url.path.split('/api/v1/corrections/').last}';

List<String> routes(List<http.Request> log) => [
  for (final request in log) route(request),
];

/// Server palsu modul. me() memberi balasan GET me/: map seperti guest, atau http.Response untuk galat.
http.Response Function(http.Request) server(Object Function() me) =>
    (request) => switch (route(request)) {
      'GET me/' => switch (me()) {
        final http.Response response => response,
        final reply => jsonResponse(jsonEncode(reply), 200),
      },
      'GET products/107/form/' => jsonResponse(formJson, 200),
      'POST mine/' => jsonResponse(correctionJson, 201),
      'GET mine/' => jsonResponse(emptyMineJson, 200),
      'GET moderation/' => jsonResponse(emptyModerationJson, 200),
      _ => jsonResponse(
        '{"detail": "Data tidak ditemukan.", "code": "product_not_found"}',
        404,
      ),
    };

/// Antrean baru (UniqueKey), jadi me/ dipanggil lagi setiap kali.
Future<void> pumpQueue(WidgetTester tester, FakeRequest request) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: request,
      child: MaterialApp(home: DataCorrectionPage(key: UniqueKey())),
    ),
  );
  await tester.pumpAndSettle();
}

/// Halaman milik anggota lain (bukan halaman modul): tombol "Bantu lengkapi data" untuk produk 107 memanggil
/// openCorrectionForm. Hasil tiap ketukan dicatat di list yang dikembalikan.
Future<List<bool>> pumpFriendPage(
  WidgetTester tester,
  FakeRequest request, {
  List<String> fields = const [],
}) async {
  final results = <bool>[];
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: request,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final sent = await openCorrectionForm(
                  context,
                  productId: 107,
                  fields: fields,
                );
                results.add(sent);
              },
              child: const Text('Bantu lengkapi data'),
            ),
          ),
        ),
      ),
    ),
  );
  return results;
}

/// Form yang sedang terbuka.
CorrectionFormPage openedForm(WidgetTester tester) =>
    tester.widget(find.byType(CorrectionFormPage));

void main() {
  testWidgets(
    'guests get the login sheet instead of the form or Pengajuan Saya',
    (tester) async {
      final log = await withMockServer(server(() => guest), () async {
        await pumpQueue(tester, FakeRequest(queueReply));
        expect(find.byTooltip('Pengajuan Saya'), findsOneWidget);
        expect(find.byTooltip('Moderasi Data'), findsNothing);

        await tester.tap(find.text('Lengkapi Data'));
        await tester.pumpAndSettle();
        expect(find.text(loginRequiredTitle), findsOneWidget);
        expect(find.text(loginRequiredMessage), findsOneWidget);
        expect(find.text('Masuk'), findsOneWidget);
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();
        expect(find.text(loginRequiredTitle), findsNothing);

        await tester.tap(find.byTooltip('Pengajuan Saya'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Daftar'));
        await tester.pumpAndSettle();
        expect(find.byType(RegisterPage), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(DataCorrectionPage), findsOneWidget);
        expect(find.byType(MyCorrectionsPage), findsNothing);
        expect(find.text(loginRequiredTitle), findsNothing);
      });
      expect(routes(log), ['GET me/']); // form dan mine/ tidak pernah diminta
    },
  );

  testWidgets(
    'logging in from the sheet comes back to the queue and continues',
    (tester) async {
      var me = guest;
      final request = FakeRequest(queueReply);
      final log = await withMockServer(server(() => me), () async {
        await pumpQueue(tester, request);
        await tester.tap(find.text('Lengkapi Data'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Masuk'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);

        // Meniru LoginPage setelah berhasil: sesi terpasang, lalu pushReplacement ke Katalog.
        request.loggedIn = true;
        me = curator;
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Katalog')),
              ),
            );
        await tester.pumpAndSettle();
        expect(find.text('Katalog'), findsNothing);
        expect(find.byType(CorrectionFormPage), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Moderasi Data'),
          findsOneWidget,
        ); // me/ dimuat ulang sesudah masuk
      });
      expect(routes(log), ['GET me/', 'GET me/', 'GET products/107/form/']);
      expect(request.urls, hasLength(1));
    },
  );

  testWidgets('Moderasi Data follows me/, not request.loggedIn or jsonData', (
    tester,
  ) async {
    var me = guest;
    final log = await withMockServer(server(() => me), () async {
      // Sesi habis: loggedIn dan jsonData masih dari login lama, tetapi me/ bilang belum masuk.
      final stale = FakeRequest(queueReply)
        ..loggedIn = true
        ..jsonData = {'is_staff': true};
      await pumpQueue(tester, stale);
      expect(find.byTooltip('Moderasi Data'), findsNothing);
      expect([stale.logoutCalls, stale.loggedIn], [1, false]);

      me = member;
      await pumpQueue(tester, FakeRequest(queueReply)..loggedIn = true);
      expect(find.byTooltip('Pengajuan Saya'), findsOneWidget);
      expect(find.byTooltip('Moderasi Data'), findsNothing);

      // Aplikasi dibuka ulang: jsonData kosong, tetapi me/ tetap mengenali kurator.
      me = curator;
      await pumpQueue(tester, FakeRequest(queueReply));
      await tester.tap(find.byTooltip('Moderasi Data'));
      await tester.pumpAndSettle();
      expect(find.byType(ModerationPage), findsOneWidget);
    });
    expect(routes(log), ['GET me/', 'GET me/', 'GET me/', 'GET moderation/']);
  });

  testWidgets(
    'when me/ fails, Moderasi Data hides and Lengkapi Data asks me/ again',
    (tester) async {
      var calls = 0;
      final log = await withMockServer(
        server(() => calls++ == 0 ? htmlResponse(500) : member),
        () async {
          await pumpQueue(tester, FakeRequest(queueReply));
          expect(find.text('BLUE BAND CAKE & COOKIE'), findsOneWidget);
          expect(find.byTooltip('Moderasi Data'), findsNothing);

          await tester.tap(find.text('Lengkapi Data'));
          await tester.pumpAndSettle();
          expect(find.text(loginRequiredTitle), findsNothing);
          expect(find.byType(CorrectionFormPage), findsOneWidget);
        },
      );
      expect(routes(log), ['GET me/', 'GET me/', 'GET products/107/form/']);
    },
  );

  testWidgets(
    'after submitting, Kembali ke Antrean Data pops back to a queue reloaded once',
    (tester) async {
      var loads = 0;
      final request = FakeRequest(() {
        final json = queueReply();
        if (loads++ > 0) {
          json['results'][0]
            ..['status'] = 'needs_verification'
            ..['status_label'] = 'Perlu verifikasi';
        }
        return json;
      });
      final log = await withMockServer(server(() => member), () async {
        await pumpQueue(tester, request);
        expect(find.text('Perlu kontribusi'), findsOneWidget);

        await tester.tap(find.text('Lengkapi Data'));
        await tester.pumpAndSettle();
        expect(
          find.text(loginRequiredTitle),
          findsNothing,
        ); // sudah masuk: tanpa sheet
        await tester.enterText(find.byType(TextFormField), '7,5');
        await tester.tap(find.text('Ajukan Koreksi'));
        await tester.pumpAndSettle();
        expect(find.text('Pengajuan berhasil dikirim'), findsNWidgets(2));
        expect(
          request.urls,
          hasLength(2),
        ); // antrean di bawahnya sudah dimuat ulang

        await tester.tap(find.text('Kembali ke Antrean Data'));
        await tester.pumpAndSettle();
        expect(
          find.byType(CorrectionDetailPage, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.byType(DataCorrectionPage, skipOffstage: false),
          findsOneWidget,
        ); // tidak menumpuk antrean baru
        expect(find.text('Perlu verifikasi'), findsOneWidget);
        expect(find.text('Perlu kontribusi'), findsNothing);
      });
      expect(request.urls, hasLength(2));
      expect(routes(log), ['GET me/', 'GET products/107/form/', 'POST mine/']);
    },
  );

  testWidgets(
    'the back button returns from every module page to the same queue',
    (tester) async {
      final request = FakeRequest(queueReply);
      final log = await withMockServer(server(() => curator), () async {
        await pumpQueue(tester, request);
        for (final open in [
          find.byTooltip('Pengajuan Saya'),
          find.byTooltip('Moderasi Data'),
          find.text('Lengkapi Data'),
        ]) {
          await tester.tap(open);
          await tester.pumpAndSettle();
          expect(
            find.byType(DataCorrectionPage),
            findsNothing,
          ); // tertutup halaman modul

          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(DataCorrectionPage), findsOneWidget);
        }
      });
      expect(
        request.urls,
        hasLength(1),
      ); // kembali tanpa hasil: antrean tidak dimuat ulang
      expect(routes(log), [
        'GET me/',
        'GET mine/',
        'GET moderation/',
        'GET products/107/form/',
      ]);
    },
  );

  testWidgets('openCorrectionForm opens the form with the given fields', (
    tester,
  ) async {
    final log = await withMockServer(server(() => member), () async {
      final results = await pumpFriendPage(
        tester,
        FakeRequest()..loggedIn = true,
        fields: ['fiber_100g', 'sodium_100g'],
      );
      await tester.tap(find.text('Bantu lengkapi data'));
      await tester.pumpAndSettle();
      expect(find.text(loginRequiredTitle), findsNothing);
      expect(openedForm(tester).productId, 107);
      expect(openedForm(tester).focus, ['fiber_100g', 'sodium_100g']);

      // Ditutup tanpa mengirim: kembali ke halaman pemanggil, hasilnya false.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CorrectionFormPage), findsNothing);
      expect(find.text('Bantu lengkapi data'), findsOneWidget);
      expect(results, [false]);
    });
    expect(routes(log), ['GET me/', 'GET products/107/form/']);
    final query = log.last.url.queryParametersAll;
    expect(query['field'], ['fiber_100g', 'sodium_100g']);
  });

  testWidgets('openCorrectionForm asks guests to log in before the form', (
    tester,
  ) async {
    var me = guest;
    final request = FakeRequest();
    final log = await withMockServer(server(() => me), () async {
      final results = await pumpFriendPage(
        tester,
        request,
        fields: ['fiber_100g'],
      );
      await tester.tap(find.text('Bantu lengkapi data'));
      await tester.pumpAndSettle();
      expect(find.text(loginRequiredTitle), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(CorrectionFormPage), findsNothing);
      expect(results, [false]);

      // Masuk lewat sheet: Katalog dari LoginPage ditutup, lalu form terbuka di atas halaman pemanggil.
      await tester.tap(find.text('Bantu lengkapi data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      // Meniru LoginPage yang berhasil: sesi terpasang, lalu pushReplacement ke Katalog.
      request.loggedIn = true;
      me = member;
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Katalog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Katalog'), findsNothing);
      expect(openedForm(tester).focus, ['fiber_100g']);
    });
    expect(routes(log), ['GET me/', 'GET me/', 'GET products/107/form/']);
  });

  testWidgets('openCorrectionForm ignores unknown field names safely', (
    tester,
  ) async {
    final log = await withMockServer(server(() => member), () async {
      await pumpFriendPage(
        tester,
        FakeRequest()..loggedIn = true,
        fields: ['harga', 'fiber_100g', 'Fiber_100g', 'fiber_100g', ''],
      );
      await tester.tap(find.text('Bantu lengkapi data'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(openedForm(tester).focus, ['fiber_100g']);
    });
    // Yang dikirim ke server hanya field yang sah, sekali.
    final query = log.last.url.queryParametersAll;
    expect(query['field'], ['fiber_100g']);
  });

  testWidgets('openCorrectionForm returns true after sending', (tester) async {
    final log = await withMockServer(server(() => member), () async {
      final results = await pumpFriendPage(
        tester,
        FakeRequest()..loggedIn = true,
        fields: ['fiber_100g'],
      );
      await tester.tap(find.text('Bantu lengkapi data'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '7,5');
      await tester.tap(find.text('Ajukan Koreksi'));
      await tester.pumpAndSettle();
      expect(find.text('Pengajuan berhasil dikirim'), findsNWidgets(2));
      expect(results, [true]); // halaman sukses masih tampil

      // Kembali dari halaman sukses: ke halaman pemanggil, bukan ke antrean.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Bantu lengkapi data'), findsOneWidget);
      expect(find.byType(DataCorrectionPage), findsNothing);
    });
    expect(routes(log), ['GET me/', 'GET products/107/form/', 'POST mine/']);
  });
}
