import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_form_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/moderation_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/my_corrections_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/review_page.dart';

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

/// Satu baris moderasi: nilai saat ini kosong, nilai produk sudah berubah sejak diajukan (stale).
Map<String, dynamic> moderationRow(int id) => {
  'id': id,
  'correction_id': 12,
  'product': product(),
  'submitted_by': 'Nama Pengaju Yang Cukup Panjang',
  'created_at': '2026-11-24T12:00:00Z',
  'field_name': 'carbohydrates_100g',
  'label': 'Karbohidrat (g/100 g)',
  'old_value': 45,
  'proposed_value': 61.25,
  'current_value': null,
  'old_display': '45',
  'proposed_display': '61,25',
  'current_display': null,
  'status': 'pending',
  'status_label': 'Menunggu',
  'review_note': '',
  'stale': true,
};

/// Halaman 1 dari 2 di tab antrean, dengan angka statistik besar dan label field panjang.
Map<String, dynamic> moderationPage() => {
  'count': 21,
  'page': 1,
  'page_size': 20,
  'num_pages': 2,
  'next_page': 2,
  'previous_page': null,
  'tab': 'antrean',
  'field': null,
  'status': null,
  'tab_options': [
    {'key': 'antrean', 'label': 'Antrean koreksi'},
    {'key': 'semua', 'label': 'Semua pengajuan'},
    {'key': 'panduan', 'label': 'Panduan field'},
  ],
  'field_options': [
    {'key': 'carbohydrates_100g', 'label': 'Karbohidrat (g/100 g)'},
    {'key': 'saturated_fat_100g', 'label': 'Lemak jenuh (g/100 g)'},
  ],
  'status_options': [],
  'stats': {'pending': 1234, 'approved': 56789, 'rejected': 321},
  'results': [moderationRow(31), moderationRow(32)],
};

/// Balasan GET moderation/guide/ dengan satu field.
const guide = {
  'fields': [
    {
      'field_name': 'carbohydrates_100g',
      'label': 'Karbohidrat (g/100 g)',
      'kind': 'Angka desimal',
      'rules': [
        'Diisi dalam g per 100 g, tanpa pemisah ribuan.',
        'Tidak boleh negatif dan tidak lebih dari 100.',
      ],
    },
  ],
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

  testWidgets('Moderasi stacks the stats at 360 dp with large text', (
    tester,
  ) async {
    final queue = jsonEncode(moderationPage());
    final fields = jsonEncode(guide);
    await withMockServer(
      (request) => jsonResponse(
        request.url.path.endsWith('/guide/') ? fields : queue,
        200,
      ),
      () async {
        await pumpNarrow(tester, const ModerationPage());
        expect(tester.takeException(), isNull);
        // Satu kolom: ikon kartu "Disetujui" tepat di bawah ikon kartu "Menunggu review".
        final pendingIcon = tester.getTopLeft(find.byIcon(Icons.schedule));
        final approvedIcon = tester.getTopLeft(
          find.byIcon(Icons.check_circle_outline),
        );
        expect(approvedIcon.dx, pendingIcon.dx);
        expect(approvedIcon.dy, greaterThan(pendingIcon.dy));
        expect(find.text('Nilai berubah'), findsNWidgets(2));
        expect(find.text('Halaman 1 dari 2'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Panduan field'));
        await tester.pumpAndSettle();
        expect(find.text('Cara meninjau'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('Moderasi keeps the three stats in one row at normal text size', (
    tester,
  ) async {
    final page = moderationPage();
    await withMockServer((_) => jsonResponse(jsonEncode(page), 200), () async {
      await pumpNarrow(tester, const ModerationPage(), textScale: 1);
      expect(tester.takeException(), isNull);
      final pendingIcon = tester.getTopLeft(find.byIcon(Icons.schedule));
      final approvedIcon = tester.getTopLeft(
        find.byIcon(Icons.check_circle_outline),
      );
      expect(approvedIcon.dy, pendingIcon.dy);
      expect(approvedIcon.dx, greaterThan(pendingIcon.dx));
    });
  });

  testWidgets('Review stacks the two values at 360 dp with large text', (
    tester,
  ) async {
    final row = moderationRow(31);
    await withMockServer((_) => jsonResponse(jsonEncode(row), 200), () async {
      await pumpNarrow(tester, const ReviewPage(itemId: 31));
      expect(tester.takeException(), isNull);
      // Satu kolom: kotak "Usulan nilai" tepat di bawah kotak "Nilai saat ini".
      final current = tester.getTopLeft(find.text('Nilai saat ini'));
      final proposed = tester.getTopLeft(find.text('Usulan nilai'));
      expect(proposed.dx, current.dx);
      expect(proposed.dy, greaterThan(current.dy));
      expect(find.textContaining('Nilai produk sudah berubah'), findsOneWidget);

      // Tolak tanpa catatan: pesan wajib tampil di bawah kotak catatan.
      await tester.tap(find.text('Tolak'));
      await tester.pumpAndSettle();
      expect(find.text(noteRequiredMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
