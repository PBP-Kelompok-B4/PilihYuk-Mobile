import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/data_correction_page.dart';

import 'data_correction_fakes.dart';

// Respons asli GET /api/v1/corrections/queue/ dari db.sqlite3 seed (results dipotong jadi 2).
const sampleJson = r'''
{"count": 347, "page": 1, "page_size": 20, "num_pages": 18, "next_page": 2, "previous_page": null,
 "sort": "shelf", "missing": null, "shelf_available": true,
 "sort_options": [{"key": "shelf", "label": "Paling sering di shelf"},
                  {"key": "kosong", "label": "Paling banyak data kosong"},
                  {"key": "terbaru", "label": "Terbaru"}],
 "missing_options": [{"key": "nutrition", "label": "Gizi"}, {"key": "nova", "label": "NOVA"},
                     {"key": "brand", "label": "Merek"}, {"key": "quantity", "label": "Isi bersih"},
                     {"key": "origin", "label": "Asal"}],
 "stats": {"incomplete_products": 347, "submitted_last_7_days": 0, "approved": 5, "shelf_average": 0.1},
 "results": [
  {"id": 107, "product_name": "BLUE BAND CAKE & COOKIE", "brand": "", "quantity": "",
   "image_url": "https://images.openfoodfacts.org/images/products/871/920/017/1466/front_en.3.400.jpg",
   "missing": [
     {"key": "nutrition", "label": "Gizi", "correctable": true,
      "fields": ["proteins_100g", "fat_100g", "saturated_fat_100g", "carbohydrates_100g", "sugars_100g", "fiber_100g", "sodium_100g"]},
     {"key": "nova", "label": "NOVA", "correctable": true, "fields": ["nova_group"]},
     {"key": "brand", "label": "Merek", "correctable": true, "fields": ["brand"]},
     {"key": "quantity", "label": "Isi bersih", "correctable": true, "fields": ["quantity"]},
     {"key": "origin", "label": "Asal", "correctable": true, "fields": ["origin"]}],
   "missing_count": 11, "shelf_count": 5, "status": "needs_verification", "status_label": "Perlu verifikasi"},
  {"id": 203, "product_name": "Prenagen mommy stroberi", "brand": "", "quantity": "",
   "image_url": "https://images.openfoodfacts.org/images/products/899/280/222/0033/front_id.3.400.jpg",
   "missing": [
     {"key": "nutrition", "label": "Gizi", "correctable": true,
      "fields": ["energy_kcal_100g", "proteins_100g", "fat_100g", "saturated_fat_100g", "carbohydrates_100g", "sugars_100g", "fiber_100g", "sodium_100g"]},
     {"key": "nova", "label": "NOVA", "correctable": true, "fields": ["nova_group"]},
     {"key": "brand", "label": "Merek", "correctable": true, "fields": ["brand"]},
     {"key": "quantity", "label": "Isi bersih", "correctable": true, "fields": ["quantity"]}],
   "missing_count": 11, "shelf_count": 5, "status": "needs_contribution", "status_label": "Perlu kontribusi"}]}
''';

Map<String, dynamic> sample() => jsonDecode(sampleJson) as Map<String, dynamic>;

/// Tanpa gambar, supaya tes tidak mengunduh dari jaringan.
Map<String, dynamic> sampleWithoutImages() {
  final json = sample();
  for (final row in json['results']) {
    row['image_url'] = '';
  }
  return json;
}

Future<FakeRequest> pumpPage(
  WidgetTester tester,
  Object? Function() reply,
) async {
  // Layar tinggi, supaya semua kartu dan tombol halaman langsung dibangun ListView.
  tester.view.physicalSize = const Size(1000, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final request = FakeRequest(reply);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: request,
      child: const MaterialApp(home: DataCorrectionPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return request;
}

void main() {
  group('CorrectionQueue.fromJson', () {
    test('reads a full response', () {
      final queue = CorrectionQueue.fromJson(sample());
      expect(
        [
          queue.count,
          queue.page,
          queue.pageSize,
          queue.numPages,
          queue.nextPage,
          queue.previousPage,
        ],
        [347, 1, 20, 18, 2, null],
      );
      expect(
        [queue.sort, queue.missing, queue.shelfAvailable],
        ['shelf', null, true],
      );
      expect(
        [for (final option in queue.sortOptions) option.key],
        ['shelf', 'kosong', 'terbaru'],
      );
      expect(
        [for (final option in queue.missingOptions) option.label],
        ['Gizi', 'NOVA', 'Merek', 'Isi bersih', 'Asal'],
      );
      expect(
        [
          queue.stats.incompleteProducts,
          queue.stats.submittedLast7Days,
          queue.stats.approved,
        ],
        [347, 0, 5],
      );
      expect(queue.stats.shelfAverage, 0.1);

      final first = queue.results.first;
      expect(
        [
          first.id,
          first.productName,
          first.brand,
          first.quantity,
          first.subtitle,
        ],
        [107, 'BLUE BAND CAKE & COOKIE', '', '', ''],
      );
      expect(first.imageUrl, startsWith('https://images.openfoodfacts.org/'));
      expect(
        [first.missingCount, first.shelfCount, first.status, first.statusLabel],
        [11, 5, 'needs_verification', 'Perlu verifikasi'],
      );
      expect(
        [for (final entry in first.missing) entry.key],
        ['nutrition', 'nova', 'brand', 'quantity', 'origin'],
      );
      expect(first.missing.first.correctable, isTrue);
      expect(first.missing.first.fields, hasLength(7));
      expect(first.missing[1].fields, ['nova_group']);
      expect(queue.results[1].status, 'needs_contribution');
    });

    test('accepts null values and an empty image_url', () {
      final json = sample()
        ..['missing'] = 'nova'
        ..['next_page'] = null
        ..['previous_page'] = 17
        ..['shelf_available'] = false;
      json['stats']['shelf_average'] = null;
      final row = json['results'][0];
      row['shelf_count'] = null;
      row['image_url'] = '';
      row['brand'] = 'Blue Band';
      row['quantity'] = '200 g';
      row['missing'] = [
        {
          'key': 'packaging',
          'label': 'Kemasan',
          'correctable': false,
          'fields': <String>[],
        },
      ];

      final queue = CorrectionQueue.fromJson(json);
      expect(
        [
          queue.missing,
          queue.nextPage,
          queue.previousPage,
          queue.shelfAvailable,
        ],
        ['nova', null, 17, false],
      );
      expect(queue.stats.shelfAverage, isNull);
      final first = queue.results.first;
      expect(
        [first.shelfCount, first.imageUrl, first.subtitle],
        [null, '', 'Blue Band · 200 g'],
      );
      expect(
        [first.missing.single.correctable, first.missing.single.fields],
        [false, isEmpty],
      );
    });

    test('shelf_average 0 from an empty queue is a double', () {
      final json = sample();
      json['stats']['shelf_average'] = 0;
      expect(CorrectionQueue.fromJson(json).stats.shelfAverage, 0.0);
    });
  });

  test('CorrectionQueue.uri leaves out null values and page 1', () {
    const base = 'http://127.0.0.1:8000';
    expect(
      CorrectionQueue.uri(base).toString(),
      '$base/api/v1/corrections/queue/',
    );
    expect(
      CorrectionQueue.uri(
        base,
        sort: 'terbaru',
        missing: 'nova',
        page: 2,
      ).toString(),
      '$base/api/v1/corrections/queue/?sort=terbaru&missing=nova&page=2',
    );
    expect(
      CorrectionQueue.uri(base, sort: 'kosong', page: 1).toString(),
      '$base/api/v1/corrections/queue/?sort=kosong',
    );
  });

  test('number formats follow the website', () {
    expect(
      [
        formatThousands(0),
        formatThousands(347),
        formatThousands(1248),
        formatThousands(1234567),
      ],
      ['0', '347', '1.248', '1.234.567'],
    );
    expect(
      [formatTimes(0.1), formatTimes(9.0), formatTimes(0), formatTimes(null)],
      ['0,1×', '9×', '0×', '—'],
    );
  });

  group('DataCorrectionPage', () {
    testWidgets('shows stats, chips, products and paging', (tester) async {
      final request = await pumpPage(tester, sampleWithoutImages);

      expect(request.urls, ['$baseUrl/api/v1/corrections/queue/']);
      expect(find.widgetWithText(AppBar, 'Antrean Data'), findsOneWidget);
      for (final label in [
        'Menunggu kontribusi',
        'Diajukan minggu ini',
        'Disetujui',
        'Rata-rata di shelf',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('347'), findsOneWidget);
      expect(find.text('0,1×'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'Paling sering di shelf'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ChoiceChip, 'Semua'), findsOneWidget);
      expect(find.text('BLUE BAND CAKE & COOKIE'), findsOneWidget);
      expect(find.text('Ada di 5 shelf'), findsNWidgets(2));
      expect(find.text('Perlu verifikasi'), findsOneWidget);
      expect(find.text('Perlu kontribusi'), findsOneWidget);
      expect(find.text('Halaman 1 dari 18'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'NOVA'));
      await tester.pump();
      await tester.pump();
      expect(
        request.urls.last,
        '$baseUrl/api/v1/corrections/queue/?sort=shelf&missing=nova',
      );

      await tester.tap(find.text('Berikutnya'));
      await tester.pump();
      await tester.pump();
      expect(
        request.urls.last,
        '$baseUrl/api/v1/corrections/queue/?sort=shelf&page=2',
      );
    });

    testWidgets('shows the error view and retries with Coba lagi', (
      tester,
    ) async {
      var calls = 0;
      final request = await pumpPage(tester, () {
        calls++;
        if (calls == 1) throw const FormatException('400');
        return sampleWithoutImages();
      });
      expect(find.widgetWithText(AppBar, 'Antrean Data'), findsOneWidget);
      expect(find.text('Gagal memuat antrean.'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      await tester.pump();
      await tester.pump();
      expect(request.urls, hasLength(2));
      expect(find.text('Gagal memuat antrean.'), findsNothing);
      expect(find.text('BLUE BAND CAKE & COOKIE'), findsOneWidget);
    });

    testWidgets('shows the empty state without a filter', (tester) async {
      await pumpPage(tester, () => emptySample(null));
      expect(find.text('Semua data produk sudah lengkap.'), findsOneWidget);
      expect(find.textContaining('Halaman'), findsNothing);
    });

    testWidgets('shows the empty state for a filter', (tester) async {
      await pumpPage(tester, () => emptySample('nova'));
      expect(
        find.text('Tidak ada produk yang kekurangan data jenis ini.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ChoiceChip, 'Semua'),
        findsOneWidget,
      ); // filter masih bisa dihapus
    });
  });
}

Map<String, dynamic> emptySample(String? missing) => sample()
  ..['count'] = 0
  ..['num_pages'] = 1
  ..['next_page'] = null
  ..['missing'] = missing
  ..['results'] = [];
