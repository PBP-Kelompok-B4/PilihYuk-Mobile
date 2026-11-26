import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/screens/data_correction/data_correction_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/moderation_page.dart';

import 'data_correction_fakes.dart';

const base = '$baseUrl/api/v1/corrections';

const optionsJson = r'''
 "tab_options": [{"key": "antrean", "label": "Antrean koreksi"}, {"key": "semua", "label": "Semua pengajuan"},
                 {"key": "panduan", "label": "Panduan field"}],
 "field_options": [{"key": "brand", "label": "Merek"}, {"key": "fiber_100g", "label": "Serat (g/100 g)"},
                   {"key": "sodium_100g", "label": "Natrium (mg/100 g)"}],
 "stats": {"pending": 3, "approved": 5, "rejected": 1},
''';

// Dua item Menunggu dari pengajuan #12 milik Budi; natrium sudah berubah sejak diajukan (stale).
const rowsJson = r'''
[{"id": 31, "correction_id": 12, "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi",
   "quantity": "88 g", "image_url": "", "is_active": true},
  "submitted_by": "Budi", "created_at": "2026-11-24T12:00:00Z", "field_name": "fiber_100g", "label": "Serat (g/100 g)",
  "old_value": null, "proposed_value": 7.5, "current_value": null, "old_display": null, "proposed_display": "7,5",
  "current_display": null, "status": "pending", "status_label": "Menunggu", "review_note": "", "stale": false},
 {"id": 32, "correction_id": 12, "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi",
   "quantity": "88 g", "image_url": "", "is_active": true},
  "submitted_by": "Budi", "created_at": "2026-11-24T12:00:00Z", "field_name": "sodium_100g",
  "label": "Natrium (mg/100 g)", "old_value": 0.7, "proposed_value": 0.5, "current_value": 0.78,
  "old_display": "700", "proposed_display": "500", "current_display": "780", "status": "pending",
  "status_label": "Menunggu", "review_note": "", "stale": true}]
''';

const guideJson = r'''
{"fields": [
  {"field_name": "brand", "label": "Merek", "kind": "Teks", "rules": ["Maksimal 255 karakter."]},
  {"field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "kind": "Angka desimal",
   "rules": ["Diisi dalam mg per 100 g, disimpan dalam gram.", "Tidak boleh negatif."]}]}
''';

/// Seperti server: mengikuti ?tab=, ?field=, dan ?status=; status_options hanya di tab semua.
String queueBody(http.Request request, {bool empty = false}) {
  final query = request.url.queryParameters;
  final all = query['tab'] == 'semua';
  final statuses = all
      ? '[{"key": "pending", "label": "Menunggu"}, {"key": "approved", "label": "Disetujui"}, '
            '{"key": "rejected", "label": "Ditolak"}]'
      : '[]';
  final results = empty ? '[]' : rowsJson;
  return '{"count": ${empty ? 0 : 2}, "page": 1, "page_size": 20, "num_pages": 1, "next_page": null, '
      '"previous_page": null, "tab": "${all ? 'semua' : 'antrean'}", '
      '"field": ${jsonEncode(query['field'])}, "status": ${jsonEncode(query['status'])}, $optionsJson'
      '"status_options": $statuses, "results": $results}';
}

http.Response server(http.Request request) =>
    request.url.path.endsWith('/guide/')
    ? jsonResponse(guideJson, 200)
    : jsonResponse(queueBody(request), 200);

void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpModeration(WidgetTester tester) async {
  useTallView(tester);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: FakeRequest(),
      child: const MaterialApp(home: ModerationPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

void main() {
  testWidgets('shows the stats and one card per item', (tester) async {
    final log = await withMockServer(server, () async {
      await pumpModeration(tester);
      expect(find.widgetWithText(AppBar, 'Moderasi Data'), findsOneWidget);
      expect(
        find.text(
          'Tinjau koreksi data produk hasil kontribusi pengguna. Setujui atau tolak per field.',
        ),
        findsOneWidget,
      );
      for (final (value, title) in [
        ('3', 'Menunggu review'),
        ('5', 'Disetujui'),
        ('1', 'Ditolak'),
      ]) {
        expect(find.text(value), findsOneWidget);
        expect(find.text(title), findsOneWidget);
      }
      expect(chip('Antrean koreksi'), findsOneWidget);
      expect(chip('Semua pengajuan'), findsOneWidget);
      expect(chip('Panduan field'), findsOneWidget);
      expect(find.text('Antrean pengajuan'), findsOneWidget);
      expect(find.text('2 item'), findsOneWidget);
      expect(
        chip('Semua status'),
        findsNothing,
      ); // status hanya di tab Semua pengajuan

      expect(find.text('Sarimi Isi 2 Goreng'), findsNWidgets(2));
      expect(find.textContaining('Budi · '), findsNWidgets(2));
      expect(
        find.textContaining('Field: Serat (g/100 g)', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Saat ini: Tidak diketahui'), findsOneWidget);
      expect(find.text('Saat ini: 780'), findsOneWidget);
      expect(
        find.textContaining('Usulan: 500', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Menunggu'), findsNWidgets(2));
      expect(find.text('Nilai berubah'), findsOneWidget);
      expect(find.text('Review'), findsNWidgets(2));

      await tester.tap(find.text('Review').first);
      await tester.pump();
      expect(find.text('Halaman review menyusul.'), findsOneWidget);
    });
    expect(log.single.url.toString(), '$base/moderation/');
  });

  testWidgets('tab, field and status chips ask for the right URLs', (
    tester,
  ) async {
    final log = await withMockServer(server, () async {
      await pumpModeration(tester);
      await tester.tap(chip('Natrium (mg/100 g)'));
      await tester.pumpAndSettle();

      await tester.tap(chip('Semua pengajuan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Semua pengajuan'),
        findsNWidgets(2),
      ); // chip tab dan judul daftar
      expect(chip('Semua status'), findsOneWidget);

      await tester.tap(chip('Disetujui'));
      await tester.pumpAndSettle();
      await tester.tap(chip('Merek'));
      await tester.pumpAndSettle();
      await tester.tap(chip('Semua status'));
      await tester.pumpAndSettle();

      await tester.tap(chip('Antrean koreksi'));
      await tester.pumpAndSettle();
      expect(chip('Semua status'), findsNothing);
    });
    expect(
      [for (final request in log) request.url.toString()],
      [
        '$base/moderation/',
        '$base/moderation/?field=sodium_100g',
        '$base/moderation/?tab=semua', // pindah tab mengosongkan filter
        '$base/moderation/?tab=semua&status=approved',
        '$base/moderation/?tab=semua&field=brand&status=approved',
        '$base/moderation/?tab=semua&field=brand',
        '$base/moderation/',
      ],
    );
  });

  testWidgets('Panduan field shows each field with its kind and rules', (
    tester,
  ) async {
    final log = await withMockServer(server, () async {
      await pumpModeration(tester);
      await tester.tap(chip('Panduan field'));
      await tester.pumpAndSettle();

      expect(
        find.text('Panduan field'),
        findsNWidgets(2),
      ); // chip tab dan judul kartu
      expect(find.textContaining('Hanya 2 field berikut'), findsOneWidget);
      expect(find.text('Angka desimal · sodium_100g'), findsOneWidget);
      expect(
        find.text('Diisi dalam mg per 100 g, disimpan dalam gram.'),
        findsOneWidget,
      );
      expect(find.text('Cara meninjau'), findsOneWidget);
      expect(find.text('Review'), findsNothing);
      expect(find.text('3'), findsOneWidget); // statistik tetap tampil
    });
    expect(
      [for (final request in log) request.url.toString()],
      ['$base/moderation/', '$base/moderation/guide/'],
    );
  });

  testWidgets('shows the empty state when nothing waits for review', (
    tester,
  ) async {
    await withMockServer(
      (request) => jsonResponse(queueBody(request, empty: true), 200),
      () async {
        await pumpModeration(tester);
        expect(
          find.text('Tidak ada pengajuan yang menunggu review.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Semua usulan sudah ditinjau. Usulan baru akan muncul di sini.',
          ),
          findsOneWidget,
        );
        expect(find.text('0 item'), findsOneWidget);
      },
    );
  });

  testWidgets('403 shows a clear message and Kembali goes back', (
    tester,
  ) async {
    await withMockServer(
      (_) => jsonResponse(
        '{"detail": "Halaman ini khusus kurator.", "code": "forbidden"}',
        403,
      ),
      () async {
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
              MaterialPageRoute<void>(builder: (_) => const ModerationPage()),
            );
        await tester.pumpAndSettle();
        expect(find.text('Halaman ini khusus kurator.'), findsOneWidget);
        expect(
          find.text('Moderasi Data hanya bisa dibuka dengan akun kurator.'),
          findsOneWidget,
        );
        expect(find.text('Coba lagi'), findsNothing);

        await tester.tap(find.text('Kembali'));
        await tester.pumpAndSettle();
        expect(find.byType(ModerationPage), findsNothing);
        expect(find.text('Halaman sebelumnya'), findsOneWidget);
      },
    );
  });

  testWidgets('the Moderasi Data action only shows for curators', (
    tester,
  ) async {
    const emptyQueue =
        '{"count": 0, "page": 1, "page_size": 20, "num_pages": 1, "next_page": null, "previous_page": null, '
        '"sort": "shelf", "missing": null, "shelf_available": true, "sort_options": [], "missing_options": [], '
        '"stats": {"incomplete_products": 0, "submitted_last_7_days": 0, "approved": 0, "shelf_average": 0}, '
        '"results": []}';
    final log = await withMockServer(server, () async {
      useTallView(tester);
      final member = FakeRequest(() => jsonDecode(emptyQueue))..loggedIn = true;
      await tester.pumpWidget(
        Provider<CookieRequest>.value(
          value: member,
          child: const MaterialApp(home: DataCorrectionPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pengajuan Saya'), findsOneWidget);
      expect(find.byTooltip('Moderasi Data'), findsNothing);

      final curator = FakeRequest(() => jsonDecode(emptyQueue))
        ..loggedIn = true
        ..jsonData = {'is_staff': true};
      await tester.pumpWidget(
        Provider<CookieRequest>.value(
          value: curator,
          child: const MaterialApp(home: DataCorrectionPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Moderasi Data'));
      await tester.pumpAndSettle();
      expect(find.byType(ModerationPage), findsOneWidget);
      expect(find.text('Antrean pengajuan'), findsOneWidget);
    });
    expect(log.single.url.toString(), '$base/moderation/');
  });
}
