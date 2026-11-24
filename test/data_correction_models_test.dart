import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';

// Balasan asli API dari data tes Django (Budi, Kurator, "Sarimi Isi 2 Goreng"); daftar panjang dipotong.
Map<String, dynamic> decode(String text) =>
    jsonDecode(text) as Map<String, dynamic>;

const formJson = r'''
{"product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true},
 "focus": ["fiber_100g", "sodium_100g"],
 "correctable_fields": [
  {"field_name": "nova_group", "label": "Grup NOVA", "group": "Tingkat pemrosesan", "type": "integer",
   "current_value": 4, "current_display": "4", "display_factor": 1,
   "help_text": "Bilangan bulat 1 sampai 4: 1 = tidak/minim diproses, 4 = ultra-proses."},
  {"field_name": "fiber_100g", "label": "Serat (g/100 g)", "group": "Gizi per 100 g", "type": "number",
   "current_value": null, "current_display": null, "display_factor": 1,
   "help_text": "Angka dalam g per 100 g, tanpa pemisah ribuan. Contoh: 7,5."},
  {"field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "group": "Gizi per 100 g", "type": "number",
   "current_value": 0.78, "current_display": "780", "display_factor": 1000,
   "help_text": "Angka dalam mg per 100 g, tanpa pemisah ribuan. Contoh: 780."}]}
''';

const correctionJson = r'''
{"id": 1, "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true},
 "status": "pending", "status_label": "Menunggu", "is_withdrawable": true, "created_at": "2026-11-24T06:16:06.274529Z",
 "items": [
  {"id": 1, "field_name": "fiber_100g", "label": "Serat (g/100 g)", "old_value": null, "proposed_value": 2.5,
   "old_display": null, "proposed_display": "2,5", "status": "pending", "status_label": "Menunggu", "review_note": ""},
  {"id": 2, "field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "old_value": 0.78, "proposed_value": 0.5,
   "old_display": "780", "proposed_display": "500", "status": "pending", "status_label": "Menunggu", "review_note": ""}]}
''';

const reviewedJson = r'''
{"id": 1, "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true},
 "status": "partial", "status_label": "Sebagian disetujui", "is_withdrawable": false, "created_at": "2026-11-24T06:16:06.274529Z",
 "items": [
  {"id": 1, "field_name": "fiber_100g", "label": "Serat (g/100 g)", "old_value": null, "proposed_value": 2.5,
   "old_display": null, "proposed_display": "2,5", "status": "rejected", "status_label": "Ditolak", "review_note": "Tidak sesuai label."},
  {"id": 2, "field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "old_value": 0.78, "proposed_value": 0.5,
   "old_display": "780", "proposed_display": "500", "status": "approved", "status_label": "Disetujui", "review_note": ""}]}
''';

const mineJson = r'''
{"count": 2, "page": 1, "page_size": 10, "num_pages": 1, "next_page": null, "previous_page": null,
 "results": [
  {"id": 2, "product": {"id": 2, "product_name": "Indomie Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true},
   "status": "pending", "status_label": "Menunggu", "is_withdrawable": true, "created_at": "2026-11-24T06:16:06.302431Z",
   "items": [{"id": 3, "field_name": "nova_group", "label": "Grup NOVA", "old_value": null, "proposed_value": 3,
              "old_display": null, "proposed_display": "3", "status": "pending", "status_label": "Menunggu", "review_note": ""}]}]}
''';

const rowJson = r'''
{"id": 2, "correction_id": 1,
 "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true},
 "submitted_by": "Budi", "created_at": "2026-11-24T06:16:06.274529Z", "field_name": "sodium_100g", "label": "Natrium (mg/100 g)",
 "old_value": 0.78, "proposed_value": 0.5, "current_value": 0.78, "old_display": "780", "proposed_display": "500",
 "current_display": "780", "status": "pending", "status_label": "Menunggu", "review_note": "", "stale": false}
''';

const moderationJson = r'''
{"count": 3, "page": 1, "page_size": 20, "num_pages": 1, "next_page": null, "previous_page": null,
 "tab": "antrean", "field": null, "status": null,
 "tab_options": [{"key": "antrean", "label": "Antrean koreksi"}, {"key": "semua", "label": "Semua pengajuan"},
                 {"key": "panduan", "label": "Panduan field"}],
 "field_options": [{"key": "product_name", "label": "Nama produk"}, {"key": "brand", "label": "Merek"}],
 "status_options": [], "stats": {"pending": 3, "approved": 0, "rejected": 0},
 "results": [
  {"id": 1, "correction_id": 1,
   "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true},
   "submitted_by": "Budi", "created_at": "2026-11-24T06:16:06.274529Z", "field_name": "fiber_100g", "label": "Serat (g/100 g)",
   "old_value": null, "proposed_value": 2.5, "current_value": null, "old_display": null, "proposed_display": "2,5",
   "current_display": null, "status": "pending", "status_label": "Menunggu", "review_note": "", "stale": false}]}
''';

const guideJson = r'''
{"fields": [
  {"field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "kind": "Angka desimal",
   "rules": ["Angka dalam mg per 100 g, tanpa pemisah ribuan. Contoh: 780.",
             "Rentang 0 sampai 100000 mg per 100 g, paling banyak 3 angka di belakang koma.",
             "Diisi dalam mg; produk menyimpannya dalam gram (dibagi 1000)."]}]}
''';

const reviewJson = r'''
{"item": {"id": 2, "correction_id": 1,
  "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true},
  "submitted_by": "Budi", "created_at": "2026-11-24T06:16:06.274529Z", "field_name": "sodium_100g", "label": "Natrium (mg/100 g)",
  "old_value": 0.78, "proposed_value": 0.5, "current_value": 0.5, "old_display": "780", "proposed_display": "500",
  "current_display": "500", "status": "approved", "status_label": "Disetujui", "review_note": "", "stale": false},
 "correction": {"id": 1, "status": "pending", "status_label": "Menunggu"},
 "product": {"id": 1, "field_name": "sodium_100g", "value": 0.5, "display": "500"},
 "stale": true,
 "message": "Natrium (mg/100 g) untuk Sarimi Isi 2 Goreng disetujui; data produk sudah diperbarui. Nilai produk sempat berubah sejak diajukan dan kini sudah ditimpa."}
''';

const rejectJson = r'''
{"item": {"id": 1, "correction_id": 1,
  "product": {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true},
  "submitted_by": "Budi", "created_at": "2026-11-24T06:16:06.274529Z", "field_name": "fiber_100g", "label": "Serat (g/100 g)",
  "old_value": null, "proposed_value": 2.5, "current_value": null, "old_display": null, "proposed_display": "2,5",
  "current_display": null, "status": "rejected", "status_label": "Ditolak", "review_note": "Tidak sesuai label.", "stale": false},
 "correction": {"id": 1, "status": "partial", "status_label": "Sebagian disetujui"},
 "product": {"id": 1, "field_name": "fiber_100g", "value": null, "display": null},
 "stale": false,
 "message": "Serat (g/100 g) untuk Sarimi Isi 2 Goreng ditolak; catatan tersimpan untuk pengaju."}
''';

void main() {
  test('Viewer reads me/ and treats missing keys as logged out', () {
    final visitor = Viewer.fromJson(
      decode('{"logged_in": false, "is_staff": false}'),
    );
    final user = Viewer.fromJson(
      decode('{"logged_in": true, "is_staff": false}'),
    );
    final curator = Viewer.fromJson(
      decode('{"logged_in": true, "is_staff": true}'),
    );
    expect([visitor.loggedIn, visitor.isStaff], [false, false]);
    expect([user.loggedIn, user.isStaff], [true, false]);
    expect([curator.loggedIn, curator.isStaff], [true, true]);
    final empty = Viewer.fromJson(<String, dynamic>{});
    expect([empty.loggedIn, empty.isStaff], [false, false]);
  });

  test('status constants match the API', () {
    expect(
      [
        CorrectionStatus.pending,
        CorrectionStatus.approved,
        CorrectionStatus.rejected,
        CorrectionStatus.partial,
      ],
      ['pending', 'approved', 'rejected', 'partial'],
    );
  });

  group('CorrectionFormData', () {
    test('reads product, focus and fields', () {
      final form = CorrectionFormData.fromJson(decode(formJson));
      expect(
        [
          form.product.id,
          form.product.displayName,
          form.product.subtitle,
          form.product.isActive,
        ],
        [1, 'Sarimi Isi 2 Goreng', 'Sarimi · 88 g', true],
      );
      expect(form.focus, ['fiber_100g', 'sodium_100g']);
      expect(
        [for (final field in form.fields) field.fieldName],
        ['nova_group', 'fiber_100g', 'sodium_100g'],
      );

      final nova = form.field('nova_group')!;
      expect(
        [
          nova.isInteger,
          nova.isNumber,
          nova.isKnown,
          nova.currentValue,
          nova.currentDisplay,
        ],
        [true, false, true, 4, '4'],
      );
      expect(nova.currentValue, isA<int>());
      final fiber = form.field('fiber_100g')!;
      expect(
        [
          fiber.isNumber,
          fiber.isKnown,
          fiber.currentValue,
          fiber.currentDisplay,
        ],
        [true, false, null, null],
      );
      expect(displayOrUnknown(fiber.currentDisplay), 'Tidak diketahui');
      final sodium = form.field('sodium_100g')!;
      expect(
        [
          sodium.currentValue,
          sodium.currentDisplay,
          sodium.displayFactor,
          sodium.group,
        ],
        [0.78, '780', 1000, 'Gizi per 100 g'],
      );
      expect(sodium.helpText, startsWith('Angka dalam mg'));
      expect(form.field('code'), isNull);
    });

    test('accepts int and double numbers and an empty product name', () {
      final json = decode(formJson);
      json['product']['product_name'] = '  ';
      json['product']['brand'] = '';
      final fields = json['correctable_fields'] as List;
      fields[1]['current_value'] = 0;
      fields[1]['current_display'] = '0';
      fields[2]['display_factor'] = 1000.0;
      final form = CorrectionFormData.fromJson(json);
      expect(
        [form.product.displayName, form.product.subtitle],
        ['Produk tanpa nama', '88 g'],
      );
      expect([form.fields[1].isKnown, form.fields[1].currentValue], [true, 0]);
      expect(form.fields[2].displayFactor, 1000);
    });
  });

  group('Correction', () {
    test('reads a new correction with null old values', () {
      final correction = Correction.fromJson(decode(correctionJson));
      expect(
        [
          correction.id,
          correction.status,
          correction.statusLabel,
          correction.isWithdrawable,
        ],
        [1, CorrectionStatus.pending, 'Menunggu', true],
      );
      expect(
        correction.createdAt,
        DateTime.utc(2026, 11, 24, 6, 16, 6, 274, 529),
      );
      expect(correction.createdAt.isUtc, isTrue);
      expect(correction.product.productName, 'Sarimi Isi 2 Goreng');

      final fiber = correction.items.first;
      expect(
        [
          fiber.fieldName,
          fiber.oldValue,
          fiber.proposedValue,
          fiber.oldDisplay,
          fiber.proposedDisplay,
        ],
        ['fiber_100g', null, 2.5, null, '2,5'],
      );
      expect([fiber.isPending, fiber.hasNote], [true, false]);
      final sodium = correction.items[1];
      expect(
        [
          sodium.oldValue,
          sodium.proposedValue,
          sodium.oldDisplay,
          sodium.proposedDisplay,
        ],
        [0.78, 0.5, '780', '500'],
      );
      expect(sodium.proposedValue, isA<double>());
    });

    test('reads a partly reviewed correction', () {
      final correction = Correction.fromJson(decode(reviewedJson));
      expect(
        [correction.status, correction.statusLabel, correction.isWithdrawable],
        [CorrectionStatus.partial, 'Sebagian disetujui', false],
      );
      final fiber = correction.items.first;
      expect(
        [
          fiber.status,
          fiber.statusLabel,
          fiber.reviewNote,
          fiber.hasNote,
          fiber.isPending,
        ],
        [
          CorrectionStatus.rejected,
          'Ditolak',
          'Tidak sesuai label.',
          true,
          false,
        ],
      );
      expect(correction.items[1].status, CorrectionStatus.approved);
    });

    test('CorrectionList reads paging and an int proposed value', () {
      final list = CorrectionList.fromJson(decode(mineJson));
      expect(
        [
          list.count,
          list.page,
          list.pageSize,
          list.numPages,
          list.nextPage,
          list.previousPage,
        ],
        [2, 1, 10, 1, null, null],
      );
      final item = list.results.single.items.single;
      expect(
        [item.fieldName, item.proposedValue, item.proposedDisplay],
        ['nova_group', 3, '3'],
      );
      expect(item.proposedValue, isA<int>());
    });

    test('CorrectionList accepts an empty page', () {
      final list = CorrectionList.fromJson(
        decode(
          '{"count": 0, "page": 1, "page_size": 10, "num_pages": 1, "next_page": null, "previous_page": null, "results": []}',
        ),
      );
      expect([list.count, list.results], [0, isEmpty]);
    });
  });

  group('Moderation', () {
    test('ModerationQueue reads options, stats and rows', () {
      final queue = ModerationQueue.fromJson(decode(moderationJson));
      expect(
        [queue.count, queue.pageSize, queue.tab, queue.field, queue.status],
        [3, 20, ModerationQueue.antrean, null, null],
      );
      expect(
        [for (final option in queue.tabOptions) option.key],
        [
          ModerationQueue.antrean,
          ModerationQueue.semua,
          ModerationQueue.panduan,
        ],
      );
      expect(
        [for (final option in queue.fieldOptions) option.label],
        ['Nama produk', 'Merek'],
      );
      expect(queue.statusOptions, isEmpty);
      expect(
        [
          queue.stats.pending,
          queue.stats.approved,
          queue.stats.rejected,
          queue.stats.total,
        ],
        [3, 0, 0, 3],
      );
      final row = queue.results.single;
      expect(
        [
          row.id,
          row.correctionId,
          row.submittedBy,
          row.fieldName,
          row.isPending,
          row.stale,
        ],
        [1, 1, 'Budi', 'fiber_100g', true, false],
      );
      expect(
        [row.oldValue, row.proposedValue, row.currentValue, row.currentDisplay],
        [null, 2.5, null, null],
      );
    });

    test('ModerationQueue reads the semua tab with status options', () {
      final json = decode(moderationJson)
        ..['tab'] = 'semua'
        ..['field'] = 'fiber_100g'
        ..['status_options'] = [
          {'key': 'pending', 'label': 'Menunggu'},
          {'key': 'approved', 'label': 'Disetujui'},
          {'key': 'rejected', 'label': 'Ditolak'},
        ];
      final queue = ModerationQueue.fromJson(json);
      expect([queue.tab, queue.field], [ModerationQueue.semua, 'fiber_100g']);
      expect(
        [for (final option in queue.statusOptions) option.key],
        ['pending', 'approved', 'rejected'],
      );
    });

    test('ModerationRow reads current value and display', () {
      final row = ModerationRow.fromJson(decode(rowJson));
      expect(
        [row.oldValue, row.proposedValue, row.currentValue],
        [0.78, 0.5, 0.78],
      );
      expect(
        [row.oldDisplay, row.proposedDisplay, row.currentDisplay],
        ['780', '500', '780'],
      );
      expect(
        [row.product.id, row.createdAt.isUtc, row.statusLabel],
        [1, true, 'Menunggu'],
      );
    });

    test('FieldGuideEntry reads moderation/guide/', () {
      final guide = FieldGuideEntry.listFromJson(decode(guideJson));
      final sodium = guide.single;
      expect(
        [sodium.fieldName, sodium.label, sodium.kind],
        ['sodium_100g', 'Natrium (mg/100 g)', 'Angka desimal'],
      );
      expect(sodium.rules, hasLength(3));
      expect(sodium.rules.last, contains('dibagi 1000'));
      expect(FieldGuideEntry.listFromJson(<String, dynamic>{}), isEmpty);
    });

    test('ReviewResult reads an approval with stale and a rejection', () {
      final approved = ReviewResult.fromJson(decode(reviewJson));
      expect(
        [
          approved.item.status,
          approved.item.stale,
          approved.item.currentDisplay,
        ],
        ['approved', false, '500'],
      );
      expect(
        [
          approved.correctionId,
          approved.correctionStatus,
          approved.correctionStatusLabel,
        ],
        [1, CorrectionStatus.pending, 'Menunggu'],
      );
      expect(
        [approved.productValue, approved.productDisplay, approved.stale],
        [0.5, '500', true],
      );
      expect(approved.message, contains('sempat berubah'));

      final rejected = ReviewResult.fromJson(decode(rejectJson));
      expect(
        [
          rejected.item.reviewNote,
          rejected.correctionStatus,
          rejected.correctionStatusLabel,
        ],
        ['Tidak sesuai label.', CorrectionStatus.partial, 'Sebagian disetujui'],
      );
      expect(
        [rejected.productValue, rejected.productDisplay, rejected.stale],
        [null, null, false],
      );
      expect(rejected.message, endsWith('catatan tersimpan untuk pengaju.'));
    });
  });

  group('ApiError.fromResponse', () {
    test('uses the module error body', () {
      final error = ApiError.fromResponse(
        400,
        decode(
          '{"detail": "Periksa kembali isian koreksi.", "code": "validation_error", '
          '"fields": {"nova_group": ["Grup NOVA harus bilangan bulat 1 sampai 4."]}}',
        ),
      );
      expect(
        [error.status, error.code, error.message],
        [400, 'validation_error', 'Periksa kembali isian koreksi.'],
      );
      expect(error.fields, {
        'nova_group': ['Grup NOVA harus bilangan bulat 1 sampai 4.'],
      });
      expect(
        error.fieldError('nova_group'),
        'Grup NOVA harus bilangan bulat 1 sampai 4.',
      );
      expect(error.fieldError('brand'), isNull);
      expect(error.toString(), 'Periksa kembali isian koreksi.');
    });

    test('reads module errors without fields', () {
      final cases = {
        400: '{"detail": "Pilih minimal satu field untuk dikoreksi.", "code": "validation_error"}',
        403: '{"detail": "Silakan masuk terlebih dahulu.", "code": "authentication_required"}',
        404: '{"detail": "Pengajuan tidak ditemukan.", "code": "correction_not_found"}',
        409: '{"detail": "Item ini sudah ditinjau.", "code": "already_reviewed"}',
      };
      for (final entry in cases.entries) {
        final error = ApiError.fromResponse(entry.key, decode(entry.value));
        expect(error.message, decode(entry.value)['detail']);
        expect(error.fields, isEmpty);
      }
      expect(
        ApiError.fromResponse(403, decode(cases[403]!)).needsLogin,
        isTrue,
      );
      final forbidden = ApiError.fromResponse(
        403,
        decode(
          '{"detail": "Halaman ini khusus kurator.", "code": "forbidden"}',
        ),
      );
      expect(
        [forbidden.needsLogin, forbidden.message],
        [false, 'Halaman ini khusus kurator.'],
      );
    });

    test('row errors and a non-list field value become lists of text', () {
      final error = ApiError.fromResponse(
        400,
        decode(
          '{"detail": "Periksa kembali isian koreksi.", "code": "validation_error", '
          '"fields": {"items": ["Baris 2, field_name: Bidang ini harus diisi."], "product": "Bidang ini harus diisi."}}',
        ),
      );
      expect(error.fields, {
        'items': ['Baris 2, field_name: Bidang ini harus diisi.'],
        'product': ['Bidang ini harus diisi.'],
      });
    });

    test('DRF errors without code use the default message per status', () {
      final csrf = ApiError.fromResponse(
        403,
        decode('{"detail": "CSRF Failed: CSRF token missing."}'),
      );
      expect(
        [csrf.code, csrf.message, csrf.needsLogin],
        [null, ApiError.defaultMessage(403), false],
      );
      final malformed = ApiError.fromResponse(
        400,
        decode('{"detail": "JSON parse error - Expecting value"}'),
      );
      expect(malformed.message, 'Periksa kembali isian.');
      final method = ApiError.fromResponse(
        405,
        decode('{"detail": "Method \\"PUT\\" not allowed."}'),
      );
      expect(method.message, 'Aksi ini tidak didukung.');
    });

    test('handles a null body, text, other shapes and the network', () {
      final network = ApiError.fromResponse(0, null);
      expect(
        [network.status, network.code, network.isNetwork],
        [0, null, true],
      );
      expect(network.message, startsWith('Tidak dapat terhubung ke server'));
      expect(
        ApiError.fromResponse(500, '<html>Server Error</html>').message,
        'Server sedang bermasalah. Coba lagi nanti.',
      );
      expect(
        ApiError.fromResponse(502, null).message,
        'Server sedang bermasalah. Coba lagi nanti.',
      );
      expect(
        ApiError.fromResponse(400, ['x']).message,
        'Periksa kembali isian.',
      );
      expect(ApiError.fromResponse(404, null).message, 'Data tidak ditemukan.');
      expect(
        ApiError.fromResponse(409, <String, dynamic>{}).message,
        'Data sudah berubah. Muat ulang lalu coba lagi.',
      );
      expect(
        ApiError.fromResponse(418, null).message,
        'Terjadi kesalahan (kode 418).',
      );
      expect(
        ApiError.fromResponse(
          400,
          decode('{"detail": "", "code": "validation_error"}'),
        ).message,
        'Periksa kembali isian.',
      );
    });
  });

  group('time helpers', () {
    final now = DateTime.utc(2026, 11, 24, 12);

    test('formatAgo uses one unit like the web filter', () {
      String ago(Duration before) => formatAgo(now.subtract(before), now: now);
      expect(ago(const Duration(seconds: 20)), 'baru saja');
      expect(ago(const Duration(minutes: 5)), '5 menit lalu');
      expect(ago(const Duration(hours: 2, minutes: 40)), '2 jam lalu');
      expect(ago(const Duration(days: 3, hours: 4)), '3 hari lalu');
      expect(ago(const Duration(days: 10)), '1 minggu lalu');
      expect(ago(const Duration(days: 45)), '1 bulan lalu');
      expect(ago(const Duration(days: 400)), '1 tahun lalu');
      expect(
        formatAgo(now.add(const Duration(minutes: 3)), now: now),
        'baru saja',
      );
    });

    test('formatAgo compares UTC from the API with local now', () {
      final created = DateTime.parse('2026-11-24T06:16:06.274529Z');
      expect(
        formatAgo(
          created,
          now: created.toLocal().add(const Duration(hours: 2)),
        ),
        '2 jam lalu',
      );
    });

    test('formatDate writes the local date in Indonesian', () {
      expect(formatDate(DateTime(2026, 11, 24, 23, 30)), '24 November 2026');
      expect(formatDate(DateTime(2026, 1, 5)), '5 Januari 2026');
      final utc = DateTime.utc(2026, 11, 24, 6);
      expect(formatDate(utc), formatDate(utc.toLocal()));
    });
  });
}
