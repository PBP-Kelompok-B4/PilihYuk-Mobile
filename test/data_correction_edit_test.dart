import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_form_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/my_corrections_page.dart';

import 'data_correction_fakes.dart';

const base = '$baseUrl/api/v1/corrections';
const notEditable =
    'Pengajuan ini sudah mulai ditinjau sehingga tidak bisa diubah.';
const notEditableJson = '{"detail": "$notEditable", "code": "not_editable"}';

Map<String, dynamic> product() => {
  'id': 1,
  'product_name': 'Sarimi Isi 2 Goreng',
  'brand': 'Sarimi',
  'quantity': '88 g',
  'image_url': '',
  'is_active': true,
};

/// Usulan serat (sebelumnya kosong), mis. fiber(31, '7,5'). approved: sudah disetujui kurator.
Map<String, dynamic> fiber(int id, String value, {bool approved = false}) => {
  'id': id,
  'field_name': 'fiber_100g',
  'label': 'Serat (g/100 g)',
  'old_value': null,
  'proposed_value': num.parse(value.replaceAll(',', '.')),
  'old_display': null,
  'proposed_display': value,
  'status': approved ? 'approved' : 'pending',
  'status_label': approved ? 'Disetujui' : 'Menunggu',
  'review_note': '',
};

/// Usulan natrium 500 mg (sebelumnya 780 mg), masih menunggu.
Map<String, dynamic> sodium(int id) => {
  'id': id,
  'field_name': 'sodium_100g',
  'label': 'Natrium (mg/100 g)',
  'old_value': 0.78,
  'proposed_value': 0.5,
  'old_display': '780',
  'proposed_display': '500',
  'status': 'pending',
  'status_label': 'Menunggu',
  'review_note': '',
};

/// Satu pengajuan, statusnya diturunkan seperti di web: "Menunggu" selama masih ada item pending, tetapi
/// is_withdrawable (boleh diubah atau ditarik) hanya bila SEMUA item masih pending.
Map<String, dynamic> correction(
  List<Map<String, dynamic>> items, {
  int id = 12,
}) {
  final statuses = [for (final item in items) item['status']];
  final waiting = statuses.contains('pending');
  return {
    'id': id,
    'product': product(),
    'status': waiting ? 'pending' : 'approved',
    'status_label': waiting ? 'Menunggu' : 'Disetujui',
    'is_withdrawable': statuses.every((status) => status == 'pending'),
    'created_at': '2026-11-24T12:00:00Z',
    'items': items,
  };
}

// editable: #12 sebelum diubah. saved: balasan PATCH setelah serat jadi 8 dan natrium dihapus (id item baru).
// inReview: #12 setelah kurator menyetujui serat. reviewed: #9 yang sudah selesai ditinjau.
final editable = correction([fiber(31, '7,5'), sodium(32)]);
final saved = correction([fiber(41, '8')]);
final inReview = correction([fiber(31, '7,5', approved: true), sodium(32)]);
final reviewed = correction([fiber(21, '2', approved: true)], id: 9);

/// Satu field angka di `GET products/<pk>/form/`; current dalam satuan kolom, display teks tampilannya.
Map<String, dynamic> field(
  String name,
  String label, {
  num? current,
  String? display,
}) => {
  'field_name': name,
  'label': label,
  'type': 'number',
  'current_value': current,
  'current_display': display,
};

final formJson = {
  'product': product(),
  'focus': <String>[],
  'correctable_fields': [
    field('fiber_100g', 'Serat (g/100 g)'),
    field('sodium_100g', 'Natrium (mg/100 g)', current: 0.78, display: '780'),
    field('proteins_100g', 'Protein (g/100 g)'),
  ],
};

/// GET mine/ dengan satu halaman.
Map<String, dynamic> minePage(List<Map<String, dynamic>> results) => {
  'count': results.length,
  'page': 1,
  'page_size': 10,
  'num_pages': 1,
  'next_page': null,
  'previous_page': null,
  'results': results,
};

http.Response reply(Object body, [int status = 200]) =>
    jsonResponse(jsonEncode(body), status);

/// "PATCH mine/12/", "GET products/1/form/", ...
String route(http.Request request) =>
    '${request.method} ${request.url.path.split('/api/v1/corrections/').last}';

List<String> routes(List<http.Request> log) => [
  for (final request in log) route(request),
];

Finder inCard(int id, String text) => find.descendant(
  of: find.byKey(ValueKey('correction-$id')),
  matching: find.text(text),
);

/// Isi kotak Usulan nilai di form, urut dari atas.
List<String> inputs(WidgetTester tester) {
  final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
  return [for (final input in fields) input.controller!.text];
}

/// Field yang terpilih di dropdown tiap baris form.
List<String?> pickedFields(WidgetTester tester) {
  final menus = tester.widgetList<DropdownButtonFormField<String>>(
    find.byType(DropdownButtonFormField<String>),
  );
  return [for (final menu in menus) menu.initialValue];
}

/// Halaman di dalam MaterialApp dengan sesi palsu. Kuncinya baru tiap kali, jadi halaman sebelumnya dibuang.
Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1000, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      key: UniqueKey(),
      value: FakeRequest(),
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

/// Detail yang dibuka dari Pengajuan Saya (bukan halaman sukses), tanpa GET.
Widget detail(Map<String, dynamic> data) => CorrectionDetailPage(
  correctionId: data['id'] as int,
  initial: Correction.fromJson(data),
);

/// Di form ubah: serat diganti 8, baris natrium dihapus, lalu Simpan perubahan.
Future<void> saveFiberOnly(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, '8');
  await tester.tap(find.byTooltip('Hapus baris ini').last);
  // Controller baris yang dihapus baru dilepas di frame berikutnya.
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Simpan perubahan'));
  await tester.pumpAndSettle();
}

void main() {
  test('update sends PATCH mine/<id>/ with the full new list', () async {
    final log = await withMockServer((_) => reply(saved), () async {
      // Protein ditambah, natrium dihapus: body berisi daftar lengkap yang baru, tanpa product.
      final correction = await CorrectionApi(FakeRequest())
          .update(12, {'fiber_100g': '8', 'proteins_100g': '3,2'});
      expect(correction.id, 12);
    });
    final request = log.single;
    expect(route(request), 'PATCH mine/12/');
    expect(request.headers['X-CSRFToken'], 't');
    expect(jsonDecode(request.body), {
      'items': [
        {'field_name': 'fiber_100g', 'proposed_value': '8'},
        {'field_name': 'proteins_100g', 'proposed_value': '3,2'},
      ],
    });
  });

  testWidgets('Ubah usulan shows only on editable cards', (tester) async {
    final list = minePage([editable, reviewed]);
    await withMockServer((_) => reply(list), () async {
      await pumpPage(tester, const MyCorrectionsPage());
      expect(inCard(12, 'Ubah usulan'), findsOneWidget);
      expect(inCard(12, 'Tarik pengajuan'), findsOneWidget);
      expect(inCard(9, 'Ubah usulan'), findsNothing);
      expect(inCard(9, 'Lihat detail'), findsOneWidget);
    });
  });

  testWidgets('detail shows Ubah usulan only when allowed', (tester) async {
    await pumpPage(tester, detail(editable));
    expect(find.text('Ubah usulan'), findsOneWidget);
    expect(find.text('Tarik pengajuan'), findsOneWidget);

    // Halaman sukses tepat setelah mengajukan: tanpa tombol ubah, sama dengan tombol tarik.
    await pumpPage(
      tester,
      CorrectionDetailPage(
        correctionId: 12,
        initial: Correction.fromJson(editable),
        justSubmitted: true,
      ),
    );
    expect(find.text('Ubah usulan'), findsNothing);

    // Serat sudah disetujui: status masih Menunggu, tetapi pengajuan tidak bisa diubah lagi.
    await pumpPage(tester, detail(inReview));
    expect(find.text('Menunggu'), findsNWidgets(2));
    expect(find.text('Ubah usulan'), findsNothing);
    expect(find.text('Tarik pengajuan'), findsNothing);
  });

  testWidgets('the form starts with the old proposals', (tester) async {
    final log = await withMockServer((_) => reply(formJson), () async {
      await pumpPage(tester, detail(editable));
      await tester.tap(find.text('Ubah usulan'));
      await tester.pumpAndSettle();

      expect(find.text('Pengajuan Saya › Pengajuan #12'), findsOneWidget);
      // Judul form; tombol "Ubah usulan" di detail tertutup form.
      expect(find.text('Ubah usulan'), findsOneWidget);
      expect(find.text('Simpan perubahan'), findsOneWidget);
      expect(find.text('Lengkapi Data'), findsNothing);
      expect(find.text('Ajukan Koreksi'), findsNothing);
      expect(pickedFields(tester), ['fiber_100g', 'sodium_100g']);
      expect(inputs(tester), ['7,5', '500']);
      expect(find.text('780'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(CorrectionFormPage), findsNothing);
      expect(find.text('Detail pengajuan'), findsOneWidget);
    });
    // Tanpa ?field= dan tanpa PATCH.
    expect(log.single.url.toString(), '$base/products/1/form/');
  });

  testWidgets('Simpan perubahan sends PATCH and updates', (tester) async {
    final log = await withMockServer(
      (request) => switch (route(request)) {
        'GET products/1/form/' => reply(formJson),
        'PATCH mine/12/' => reply(saved),
        _ => reply({}, 404),
      },
      () async {
        await pumpPage(tester, detail(editable));
        await tester.tap(find.text('Ubah usulan'));
        await tester.pumpAndSettle();
        await saveFiberOnly(tester);

        expect(find.byType(CorrectionFormPage), findsNothing);
        expect(find.text(updatedMessage), findsOneWidget);
        expect(find.text('Detail pengajuan'), findsOneWidget);
        expect(
          find.textContaining('8 · belum disetujui', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Natrium (mg/100 g)'), findsNothing);
        expect(find.text('Ubah usulan'), findsOneWidget);
      },
    );
    // Detail memakai balasan PATCH, tanpa GET mine/12/.
    expect(routes(log), ['GET products/1/form/', 'PATCH mine/12/']);
    expect(log.last.headers['X-CSRFToken'], 't');
    expect(jsonDecode(log.last.body), {
      'items': [
        {'field_name': 'fiber_100g', 'proposed_value': '8'},
      ],
    });
  });

  testWidgets('409 shows the message and reloads', (tester) async {
    final log = await withMockServer(
      (request) => switch (route(request)) {
        'GET products/1/form/' => reply(formJson),
        'PATCH mine/12/' => jsonResponse(notEditableJson, 409),
        _ => reply(inReview),
      },
      () async {
        await pumpPage(tester, detail(editable));
        await tester.tap(find.text('Ubah usulan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simpan perubahan'));
        await tester.pumpAndSettle();

        expect(find.text(notEditable), findsOneWidget);
        expect(find.byType(CorrectionFormPage), findsNothing);
        // Detail dimuat ulang: serat sudah disetujui, jadi ubah dan tarik hilang.
        expect(find.text('Disetujui'), findsOneWidget);
        expect(find.text('Ubah usulan'), findsNothing);
        expect(find.text('Tarik pengajuan'), findsNothing);
      },
    );
    expect(routes(log), [
      'GET products/1/form/',
      'PATCH mine/12/',
      'GET mine/12/',
    ]);
  });

  testWidgets('saving from the list reloads the list', (tester) async {
    var patched = false;
    final log = await withMockServer(
      (request) {
        if (request.method == 'PATCH') {
          patched = true;
          return reply(saved);
        }
        return route(request) == 'GET mine/'
            ? reply(minePage([patched ? saved : editable]))
            : reply(formJson);
      },
      () async {
        await pumpPage(tester, const MyCorrectionsPage());
        await tester.tap(inCard(12, 'Ubah usulan'));
        await tester.pumpAndSettle();
        await saveFiberOnly(tester);

        expect(find.byType(CorrectionFormPage), findsNothing);
        expect(find.byType(MyCorrectionsPage), findsOneWidget);
        expect(find.text(updatedMessage), findsOneWidget);
        expect(
          find.textContaining('Tidak diketahui → 8', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('780 → 500', findRichText: true),
          findsNothing,
        );
      },
    );
    expect(routes(log), [
      'GET mine/',
      'GET products/1/form/',
      'PATCH mine/12/',
      'GET mine/',
    ]);
  });
}
