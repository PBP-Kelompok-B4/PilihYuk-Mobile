import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/screens/data_correction/moderation_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/review_page.dart';

import 'data_correction_fakes.dart';

const base = '$baseUrl/api/v1/corrections';

// Item #31 (Serat) dari pengajuan #12 milik Budi, masih Menunggu.
Map<String, dynamic> row({
  String status = 'pending',
  String statusLabel = 'Menunggu',
  String note = '',
  bool active = true,
  bool stale = false,
}) => {
  'id': 31,
  'correction_id': 12,
  'product': {
    'id': 1,
    'product_name': 'Sarimi Isi 2 Goreng',
    'brand': 'Sarimi',
    'quantity': '88 g',
    'image_url': '',
    'is_active': active,
  },
  'submitted_by': 'Budi',
  'created_at': '2026-11-24T12:00:00Z',
  'field_name': 'fiber_100g',
  'label': 'Serat (g/100 g)',
  'old_value': stale ? 2 : null,
  'proposed_value': 7.5,
  'current_value': stale ? 3 : null,
  'old_display': stale ? '2' : null,
  'proposed_display': '7,5',
  'current_display': stale ? '3' : null,
  'status': status,
  'status_label': statusLabel,
  'review_note': note,
  'stale': stale,
};

const approvedMessage =
    'Serat (g/100 g) untuk Sarimi Isi 2 Goreng disetujui; data produk sudah diperbarui.';
const rejectedMessage =
    'Serat (g/100 g) untuk Sarimi Isi 2 Goreng ditolak; catatan tersimpan untuk pengaju.';

/// Balasan PATCH berhasil, bentuknya sama dengan review_data di api_views.py.
http.Response reviewed(http.Request request) {
  final status =
      (jsonDecode(request.body) as Map<String, dynamic>)['status'] as String;
  final approved = status == 'approved';
  return jsonResponse(
    jsonEncode({
      'item': row(
        status: status,
        statusLabel: approved ? 'Disetujui' : 'Ditolak',
      ),
      'correction': {
        'id': 12,
        'status': status,
        'status_label': approved ? 'Disetujui' : 'Ditolak',
      },
      'product': {
        'id': 1,
        'field_name': 'fiber_100g',
        'value': approved ? 7.5 : null,
        'display': approved ? '7,5' : null,
      },
      'stale': false,
      'message': approved ? approvedMessage : rejectedMessage,
    }),
    200,
  );
}

/// GET item mengembalikan item; PATCH memakai patch (bawaan: berhasil).
http.Response Function(http.Request) itemServer(
  Map<String, dynamic> item, [
  http.Response Function(http.Request) patch = reviewed,
]) =>
    (request) => request.method == 'PATCH'
    ? patch(request)
    : jsonResponse(jsonEncode(item), 200);

List<http.Request> patches(List<http.Request> log) => [
  for (final request in log)
    if (request.method == 'PATCH') request,
];

/// FilledButton.icon membuat subkelas FilledButton, jadi dicari dengan `is`, bukan byType.
FilledButton button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );

Object? popResult;

/// Membuka ReviewPage di atas halaman lain supaya hasil pop bisa diperiksa.
Future<void> pumpReview(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  popResult = 'masih terbuka';
  await tester.pumpWidget(
    Provider<CookieRequest>.value(
      value: FakeRequest(),
      child: const MaterialApp(home: Scaffold(body: Text('Antrean'))),
    ),
  );
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push<bool>(
        MaterialPageRoute(builder: (_) => const ReviewPage(itemId: 31)),
      )
      .then((value) => popResult = value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the item, both values and the note field', (tester) async {
    final log = await withMockServer(itemServer(row()), () async {
      await pumpReview(tester);
      expect(find.widgetWithText(AppBar, 'Review pengajuan'), findsOneWidget);
      expect(find.text('Menunggu'), findsOneWidget);
      expect(find.textContaining('Sumber: Budi · '), findsOneWidget);
      expect(
        find.text('Pengajuan #12 · diajukan 24 November 2026'),
        findsOneWidget,
      );
      expect(find.text('Sarimi Isi 2 Goreng'), findsOneWidget);
      expect(
        find.text('Sarimi · 88 g · Field: Serat (g/100 g)'),
        findsOneWidget,
      );
      expect(find.text('Nilai saat ini'), findsOneWidget);
      expect(find.text('Tidak diketahui'), findsOneWidget);
      expect(find.text('Usulan nilai'), findsOneWidget);
      expect(find.text('7,5'), findsOneWidget);
      expect(find.text('Catatan untuk pengaju'), findsOneWidget);
      expect(find.textContaining('Wajib diisi saat menolak'), findsOneWidget);
      expect(find.text('Setujui'), findsOneWidget);
      expect(find.text('Tolak'), findsOneWidget);
      expect(find.text('Kembali ke antrean'), findsOneWidget);
      expect(find.text('Produk ini sudah tidak aktif.'), findsNothing);
      expect(find.textContaining('Nilai produk sudah berubah'), findsNothing);
    });
    expect(log.single.url.toString(), '$base/moderation/items/31/');
  });

  testWidgets('Setujui sends approved and closes with true', (tester) async {
    final log = await withMockServer(itemServer(row()), () async {
      await pumpReview(tester);
      await tester.enterText(find.byType(TextFormField), 'Sesuai foto label.');
      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewPage), findsNothing);
      expect(find.text(approvedMessage), findsOneWidget);
    });
    expect(popResult, isTrue);
    final patch = patches(log).single;
    expect(
      [patch.url.toString(), patch.headers['X-CSRFToken']],
      ['$base/moderation/items/31/', 't'],
    );
    expect(jsonDecode(patch.body), {
      'status': 'approved',
      'review_note': 'Sesuai foto label.',
    });
  });

  testWidgets(
    'Tolak needs a note, asks for confirmation, then sends rejected',
    (tester) async {
      final log = await withMockServer(itemServer(row()), () async {
        await pumpReview(tester);
        await tester.tap(find.text('Tolak'));
        await tester.pumpAndSettle();
        expect(find.text(noteRequiredMessage), findsOneWidget);
        expect(find.text('Tolak usulan ini?'), findsNothing);

        await tester.enterText(
          find.byType(TextFormField),
          'Tidak sesuai label.',
        );
        // Teks galat memudar dulu (animasi InputDecorator), baru hilang dari pohon widget.
        await tester.pumpAndSettle();
        expect(find.text(noteRequiredMessage), findsNothing);

        await tester.tap(find.text('Tolak'));
        await tester.pumpAndSettle();
        expect(find.text('Tolak usulan ini?'), findsOneWidget);
        expect(
          find.text(
            'Usulan Serat (g/100 g) untuk Sarimi Isi 2 Goreng tidak dipakai. Catatanmu dikirim ke pengaju.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewPage), findsOneWidget);

        await tester.tap(find.text('Tolak'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tolak Usulan'));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewPage), findsNothing);
        expect(find.text(rejectedMessage), findsOneWidget);
      });
      expect(popResult, isTrue);
      expect(jsonDecode(patches(log).single.body), {
        'status': 'rejected',
        'review_note': 'Tidak sesuai label.',
      });
    },
  );

  testWidgets('409 already_reviewed shows the message and closes with true', (
    tester,
  ) async {
    await withMockServer(
      itemServer(
        row(),
        (_) => jsonResponse(
          '{"detail": "Item ini sudah ditinjau.", "code": "already_reviewed"}',
          409,
        ),
      ),
      () async {
        await pumpReview(tester);
        await tester.tap(find.text('Setujui'));
        await tester.pumpAndSettle();
        expect(find.text('Item ini sudah ditinjau.'), findsOneWidget);
        expect(find.byType(ReviewPage), findsNothing);
      },
    );
    expect(popResult, isTrue);
  });

  testWidgets('400 puts the server message under the note field', (
    tester,
  ) async {
    const body =
        '{"detail": "Periksa kembali isian koreksi.", "code": "validation_error", '
        '"fields": {"review_note": ["Pastikan isian ini tidak lebih dari 1000 karakter."]}}';
    await withMockServer(
      itemServer(row(), (_) => jsonResponse(body, 400)),
      () async {
        await pumpReview(tester);
        await tester.tap(find.text('Setujui'));
        await tester.pumpAndSettle();
        expect(
          find.text('Pastikan isian ini tidak lebih dari 1000 karakter.'),
          findsOneWidget,
        );
        expect(find.byType(ReviewPage), findsOneWidget);
        expect(button(tester, 'Setujui').onPressed, isNotNull);
      },
    );
    expect(popResult, 'masih terbuka');
  });

  testWidgets('warns when the product value changed since it was submitted', (
    tester,
  ) async {
    await withMockServer(itemServer(row(stale: true)), () async {
      await pumpReview(tester);
      expect(
        find.text(
          'Nilai produk sudah berubah sejak diajukan (saat diajukan: 2). Menyetujui akan menimpa nilai sekarang.',
        ),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget); // nilai saat ini
    });
  });

  testWidgets('an inactive product can only be rejected', (tester) async {
    await withMockServer(itemServer(row(active: false)), () async {
      await pumpReview(tester);
      expect(find.text('Produk ini sudah tidak aktif.'), findsOneWidget);
      expect(find.text('Setujui'), findsNothing);
      expect(find.text('Tolak'), findsOneWidget);
      expect(
        find.text('Usulan untuk produk nonaktif hanya bisa ditolak.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a reviewed item shows its status and note without actions', (
    tester,
  ) async {
    final item = row(
      status: 'rejected',
      statusLabel: 'Ditolak',
      note: 'Tidak sesuai label.',
    );
    await withMockServer(itemServer(item), () async {
      await pumpReview(tester);
      expect(find.text('Item ini sudah ditinjau (ditolak).'), findsOneWidget);
      expect(find.text('Catatan kurator: Tidak sesuai label.'), findsOneWidget);
      expect(find.text('Catatan untuk pengaju'), findsNothing);
      expect(find.text('Setujui'), findsNothing);
      expect(find.text('Tolak'), findsNothing);
    });
  });

  testWidgets(
    'Review on the moderation page opens the item and reloads after approval',
    (tester) async {
      var approved = false;
      String queue() => jsonEncode({
        'count': 1,
        'page': 1,
        'page_size': 20,
        'num_pages': 1,
        'next_page': null,
        'previous_page': null,
        'tab': 'antrean',
        'field': null,
        'status': null,
        'tab_options': [
          {'key': 'antrean', 'label': 'Antrean koreksi'},
        ],
        'field_options': <Object>[],
        'status_options': <Object>[],
        'stats': {
          'pending': approved ? 0 : 1,
          'approved': approved ? 1 : 0,
          'rejected': 0,
        },
        'results': approved ? <Object>[] : [row()],
      });
      final log = await withMockServer(
        (request) {
          if (request.method == 'PATCH') {
            approved = true;
            return reviewed(request);
          }
          if (request.url.path.endsWith('/items/31/')) {
            return jsonResponse(jsonEncode(row()), 200);
          }
          return jsonResponse(queue(), 200);
        },
        () async {
          tester.view.physicalSize = const Size(1000, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            Provider<CookieRequest>.value(
              value: FakeRequest(),
              child: const MaterialApp(home: ModerationPage()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Review'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Setujui'));
          await tester.pumpAndSettle();

          expect(find.byType(ModerationPage), findsOneWidget);
          expect(
            find.text('Tidak ada pengajuan yang menunggu review.'),
            findsOneWidget,
          );
          expect(find.text(approvedMessage), findsOneWidget);
        },
      );
      expect(
        [for (final request in log) '${request.method} ${request.url}'],
        [
          'GET $base/moderation/',
          'GET $base/moderation/items/31/',
          'PATCH $base/moderation/items/31/',
          'GET $base/moderation/',
        ],
      );
    },
  );
}
