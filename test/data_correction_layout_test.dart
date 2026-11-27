import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_form_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/my_corrections_page.dart';

import 'data_correction_fakes.dart';

// Nama, merek, label, dan catatan panjang supaya baris dan chip terisi penuh di layar 360 dp.
const longName =
    'Biskuit Gandum Utuh Rasa Cokelat Kacang Almond Ekstra Renyah Kemasan Keluarga';
const longNote =
    'Tidak sesuai label kemasan yang tercetak di bagian belakang bungkus.';

Map<String, dynamic> product() => {
  'id': 1,
  'product_name': longName,
  'brand': 'Merek Biskuit Nusantara Sejahtera',
  'quantity': '1,25 kg',
  'image_url': '',
  'is_active': true,
};

Map<String, dynamic> item(
  int id,
  String status,
  String statusLabel, {
  String note = '',
}) => {
  'id': id,
  'field_name': 'carbohydrates_100g',
  'label': 'Karbohidrat (g/100 g)',
  'old_value': null,
  'proposed_value': 61.25,
  'old_display': null,
  'proposed_display': '61,25',
  'status': status,
  'status_label': statusLabel,
  'review_note': note,
};

/// #12 masih menunggu (bisa ditarik); #9 sebagian disetujui dengan catatan kurator.
Map<String, dynamic> pending() => {
  'id': 12,
  'product': product(),
  'status': 'pending',
  'status_label': 'Menunggu',
  'is_withdrawable': true,
  'created_at': '2026-11-24T12:00:00Z',
  'items': [item(31, 'pending', 'Menunggu'), item(32, 'pending', 'Menunggu')],
};

Map<String, dynamic> partial() => {
  'id': 9,
  'product': product(),
  'status': 'partial',
  'status_label': 'Sebagian disetujui',
  'is_withdrawable': false,
  'created_at': '2026-11-20T12:00:00Z',
  'items': [
    item(21, 'approved', 'Disetujui'),
    item(22, 'rejected', 'Ditolak', note: longNote),
  ],
};

Map<String, dynamic> field(String name, String label, {Object? current}) => {
  'field_name': name,
  'label': label,
  'group': 'Gizi per 100 g',
  'type': 'number',
  'current_value': current,
  'current_display': current == null ? null : '$current'.replaceAll('.', ','),
  'display_factor': 1,
  'help_text': 'Angka dalam g per 100 g, tanpa pemisah ribuan. Contoh: 7,5.',
};

/// Lebar 360 dp dengan huruf 1,3×, seperti ukuran font terbesar di banyak ponsel Android.
Future<void> pumpNarrow(
  WidgetTester tester,
  Widget page, {
  double textScale = 1.3,
}) async {
  tester.view.physicalSize = const Size(360, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: FakeRequest(),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pengajuan Saya fits 360 dp with large text', (tester) async {
    final page = {
      'count': 11,
      'page': 1,
      'page_size': 10,
      'num_pages': 2,
      'next_page': 2,
      'previous_page': null,
      'results': [pending(), partial()],
    };
    await withMockServer((_) => jsonResponse(jsonEncode(page), 200), () async {
      await pumpNarrow(tester, const MyCorrectionsPage());
      expect(tester.takeException(), isNull);
      expect(find.text('Tarik pengajuan'), findsOneWidget);
      expect(find.text('Catatan kurator: $longNote'), findsOneWidget);
      expect(find.text('Halaman 1 dari 2'), findsOneWidget);
    });
  });

  testWidgets('the success page fits 360 dp with large text', (tester) async {
    await pumpNarrow(
      tester,
      CorrectionDetailPage(
        correctionId: 12,
        initial: Correction.fromJson(pending()),
        justSubmitted: true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Pengajuan berhasil dikirim'), findsNWidgets(2));
    expect(find.text('Kembali ke Antrean Data'), findsOneWidget);
  });

  testWidgets('a reviewed correction with a note fits 360 dp with large text', (
    tester,
  ) async {
    await pumpNarrow(
      tester,
      CorrectionDetailPage(
        correctionId: 9,
        initial: Correction.fromJson(partial()),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Detail pengajuan'), findsOneWidget);
    expect(find.text('Nilai saat diajukan'), findsNWidgets(2));
  });

  testWidgets('the form fits 360 dp with long field names and errors', (
    tester,
  ) async {
    final form = {
      'product': product(),
      'focus': ['carbohydrates_100g', 'saturated_fat_100g'],
      'correctable_fields': [
        field('carbohydrates_100g', 'Karbohidrat (g/100 g)'),
        field('saturated_fat_100g', 'Lemak jenuh (g/100 g)', current: 1.5),
      ],
    };
    await withMockServer((_) => jsonResponse(jsonEncode(form), 200), () async {
      await pumpNarrow(
        tester,
        const CorrectionFormPage(
          productId: 1,
          focus: ['carbohydrates_100g', 'saturated_fat_100g'],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Hapus baris ini'), findsNWidgets(2));

      // Kirim tanpa isian: pesan wajib di tiap baris dan kotak galat ikut tampil.
      await tester.tap(find.text('Ajukan Koreksi'));
      await tester.pumpAndSettle();
      expect(find.text(noneFilledMessage), findsOneWidget);
      expect(find.text(requiredMessage), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
