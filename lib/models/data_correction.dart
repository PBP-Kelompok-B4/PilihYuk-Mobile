/// Satu jenis data yang kurang, mis. {"key": "nutrition", "label": "Gizi", ...}.
/// correctable false berarti hanya informasi (mis. Kemasan), fields-nya kosong.
class MissingData {
  final String key;
  final String label;
  final bool correctable;
  final List<String> fields;

  MissingData.fromJson(Map<String, dynamic> json)
    : key = json['key'],
      label = json['label'],
      correctable = json['correctable'],
      fields = [for (final field in json['fields']) field as String];
}

/// Satu produk di antrean.
class QueueProduct {
  static const needsVerification = 'needs_verification';

  final int id;
  final String productName;
  final String brand;
  final String quantity;
  final String imageUrl; // "" kalau produk tidak punya gambar
  final List<MissingData> missing;
  final int missingCount;
  final int? shelfCount; // null kalau data shelf tidak tersedia
  final String status; // needs_contribution atau needs_verification
  final String statusLabel;

  QueueProduct.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      productName = json['product_name'],
      brand = json['brand'],
      quantity = json['quantity'],
      imageUrl = json['image_url'] ?? '',
      missing = [
        for (final entry in json['missing']) MissingData.fromJson(entry),
      ],
      missingCount = json['missing_count'],
      shelfCount = json['shelf_count'],
      status = json['status'],
      statusLabel = json['status_label'];

  /// "Merek · isi", bagian yang kosong dilewati. "" kalau keduanya kosong.
  String get subtitle =>
      [brand, quantity].where((part) => part.trim().isNotEmpty).join(' · ');
}

/// Kartu statistik di atas antrean.
class QueueStats {
  final int incompleteProducts;
  final int submittedLast7Days;
  final int approved;
  final double? shelfAverage; // null kalau data shelf tidak tersedia

  QueueStats.fromJson(Map<String, dynamic> json)
    : incompleteProducts = json['incomplete_products'],
      submittedLast7Days = json['submitted_last_7_days'],
      approved = json['approved'],
      shelfAverage = (json['shelf_average'] as num?)?.toDouble();
}

/// Satu pilihan chip urutan atau filter, mis. {"key": "terbaru", "label": "Terbaru"}.
class QueueOption {
  final String key;
  final String label;

  QueueOption.fromJson(Map<String, dynamic> json)
    : key = json['key'],
      label = json['label'];
}

/// Satu halaman antrean kontribusi.
class CorrectionQueue {
  final int count;
  final int page;
  final int pageSize;
  final int numPages;
  final int? nextPage;
  final int? previousPage;
  final String sort; // urutan yang benar-benar dipakai server
  final String? missing; // null = semua jenis data
  final bool shelfAvailable;
  final List<QueueOption> sortOptions;
  final List<QueueOption> missingOptions;
  final QueueStats stats;
  final List<QueueProduct> results;

  CorrectionQueue.fromJson(Map<String, dynamic> json)
    : count = json['count'],
      page = json['page'],
      pageSize = json['page_size'],
      numPages = json['num_pages'],
      nextPage = json['next_page'],
      previousPage = json['previous_page'],
      sort = json['sort'],
      missing = json['missing'],
      shelfAvailable = json['shelf_available'],
      sortOptions = [
        for (final option in json['sort_options']) QueueOption.fromJson(option),
      ],
      missingOptions = [
        for (final option in json['missing_options'])
          QueueOption.fromJson(option),
      ],
      stats = QueueStats.fromJson(json['stats']),
      results = [for (final row in json['results']) QueueProduct.fromJson(row)];

  /// Alamat endpoint dengan query. Nilai null dan halaman 1 tidak ditulis.
  /// Contoh: uri(base, sort: 'terbaru', page: 2) -> base/api/v1/corrections/queue/?sort=terbaru&page=2
  static Uri uri(
    String baseUrl, {
    String? sort,
    String? missing,
    int page = 1,
  }) {
    final query = {
      'sort': ?sort,
      'missing': ?missing,
      if (page > 1) 'page': '$page',
    };
    return Uri.parse('$baseUrl/api/v1/corrections/queue/')
        .replace(queryParameters: query.isEmpty ? null : query);
  }
}

/// Bilangan bulat dengan pemisah ribuan format Indonesia: 1248 -> "1.248".
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Rata-rata kemunculan seperti di web: 0.1 -> "0,1×", 9.0 -> "9×", null -> "—".
String formatTimes(double? value) {
  if (value == null) return '—';
  final text = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')}×';
}

// ===== Koreksi, moderasi, dan galat (kontrak: .ai/data_correction/API.md di repo web) =====

/// Status item dan pengajuan, sama dengan web. partial hanya untuk pengajuan.
abstract final class CorrectionStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const partial = 'partial';
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) => [
  for (final entry in (value as List?) ?? const [])
    parse(entry as Map<String, dynamic>),
];

List<String> _strings(Object? value) => [
  for (final item in (value as List?) ?? const []) '$item',
];

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// Teks tampilan dari API (*_display); null berarti nilainya tidak diketahui.
String displayOrUnknown(String? display) => display ?? 'Tidak diketahui';

/// GET me/: {"logged_in": true, "is_staff": false}. Sesi kedaluwarsa dibaca sebagai belum masuk.
class Viewer {
  final bool loggedIn;
  final bool isStaff;

  const Viewer({this.loggedIn = false, this.isStaff = false});

  Viewer.fromJson(Map<String, dynamic> json)
    : loggedIn = json['logged_in'] == true,
      isStaff = json['is_staff'] == true;
}

/// {"id": 1, "product_name": "Sarimi Isi 2 Goreng", "brand": "Sarimi", "quantity": "88 g", "image_url": "", "is_active": true}
class CorrectionProduct {
  final int id;
  final String productName;
  final String brand;
  final String quantity;
  final String imageUrl; // "" kalau tidak punya gambar
  final bool isActive;

  CorrectionProduct.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      productName = json['product_name'] as String? ?? '',
      brand = json['brand'] as String? ?? '',
      quantity = json['quantity'] as String? ?? '',
      imageUrl = json['image_url'] as String? ?? '',
      isActive = json['is_active'] as bool? ?? true;

  String get displayName =>
      productName.trim().isEmpty ? 'Produk tanpa nama' : productName;

  /// "Merek · isi", bagian yang kosong dilewati.
  String get subtitle =>
      [brand, quantity].where((part) => part.trim().isNotEmpty).join(' · ');
}

/// Satu field di `GET products/<pk>/form/`, mis. {"field_name": "sodium_100g", "label": "Natrium (mg/100 g)",
/// "group": "Gizi per 100 g", "type": "number", "current_value": 0.78, "current_display": "780", "display_factor": 1000, ...}
class CorrectionField {
  static const text = 'text';
  static const integer = 'integer';
  static const number = 'number';

  final String fieldName;
  final String label;
  final String group;
  final String type;
  final Object?
  currentValue; // satuan kolom (natrium gram); null = tidak diketahui
  final String? currentDisplay;
  final int
  displayFactor; // 1000 untuk natrium (kotak isian dalam mg), 1 untuk lainnya
  final String helpText;

  CorrectionField.fromJson(Map<String, dynamic> json)
    : fieldName = json['field_name'] as String,
      label = json['label'] as String? ?? '',
      group = json['group'] as String? ?? '',
      type = json['type'] as String? ?? text,
      currentValue = json['current_value'],
      currentDisplay = json['current_display'] as String?,
      displayFactor = (json['display_factor'] as num?)?.toInt() ?? 1,
      helpText = json['help_text'] as String? ?? '';

  bool get isNumber => type == number; // angka desimal
  bool get isInteger => type == integer;
  bool get isKnown => currentValue != null;
}

/// `GET products/<pk>/form/`: product, focus (field dari ?field=), dan 14 field.
class CorrectionFormData {
  final CorrectionProduct product;
  final List<String> focus;
  final List<CorrectionField> fields;

  CorrectionFormData.fromJson(Map<String, dynamic> json)
    : product = CorrectionProduct.fromJson(_map(json['product'])),
      focus = _strings(json['focus']),
      fields = _list(json['correctable_fields'], CorrectionField.fromJson);

  CorrectionField? field(String name) {
    for (final entry in fields) {
      if (entry.fieldName == name) return entry;
    }
    return null;
  }
}

/// Satu item pengajuan, mis. {"id": 2, "field_name": "sodium_100g", "old_value": 0.78, "proposed_value": 0.5,
/// "old_display": "780", "proposed_display": "500", "status": "pending", ...}
class CorrectionItem {
  final int id;
  final String fieldName;
  final String label;
  final Object? oldValue;
  final Object? proposedValue;
  final String? oldDisplay;
  final String? proposedDisplay;
  final String status;
  final String statusLabel;
  final String reviewNote;

  CorrectionItem.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      fieldName = json['field_name'] as String,
      label = json['label'] as String? ?? '',
      oldValue = json['old_value'],
      proposedValue = json['proposed_value'],
      oldDisplay = json['old_display'] as String?,
      proposedDisplay = json['proposed_display'] as String?,
      status = json['status'] as String? ?? CorrectionStatus.pending,
      statusLabel = json['status_label'] as String? ?? '',
      reviewNote = json['review_note'] as String? ?? '';

  bool get isPending => status == CorrectionStatus.pending;
  bool get hasNote => reviewNote.trim().isNotEmpty;
}

/// Satu pengajuan (`POST mine/`, `GET mine/<pk>/`, baris `GET mine/`).
class Correction {
  final int id;
  final CorrectionProduct product;
  final String status; // CorrectionStatus, diturunkan dari item
  final String statusLabel;
  final bool isWithdrawable;
  final DateTime createdAt; // UTC
  final List<CorrectionItem> items;

  Correction.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      product = CorrectionProduct.fromJson(_map(json['product'])),
      status = json['status'] as String? ?? CorrectionStatus.pending,
      statusLabel = json['status_label'] as String? ?? '',
      isWithdrawable = json['is_withdrawable'] == true,
      createdAt = DateTime.parse(json['created_at'] as String),
      items = _list(json['items'], CorrectionItem.fromJson);
}

/// GET mine/: Pengajuan Saya, 10 per halaman.
class CorrectionList {
  final int count;
  final int page;
  final int pageSize;
  final int numPages;
  final int? nextPage;
  final int? previousPage;
  final List<Correction> results;

  CorrectionList.fromJson(Map<String, dynamic> json)
    : count = json['count'] as int,
      page = json['page'] as int,
      pageSize = json['page_size'] as int,
      numPages = json['num_pages'] as int,
      nextPage = json['next_page'] as int?,
      previousPage = json['previous_page'] as int?,
      results = _list(json['results'], Correction.fromJson);
}

/// Satu baris antrean kurator (`GET moderation/`, `GET moderation/items/<pk>/`). Pengaju hanya nama tampilan.
class ModerationRow {
  final int id;
  final int correctionId;
  final CorrectionProduct product;
  final String submittedBy;
  final DateTime createdAt;
  final String fieldName;
  final String label;
  final Object? oldValue;
  final Object? proposedValue;
  final Object? currentValue; // nilai produk sekarang
  final String? oldDisplay;
  final String? proposedDisplay;
  final String? currentDisplay;
  final String status;
  final String statusLabel;
  final String reviewNote;
  final bool
  stale; // item Menunggu dan nilai produk sudah berubah sejak diajukan

  ModerationRow.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      correctionId = json['correction_id'] as int,
      product = CorrectionProduct.fromJson(_map(json['product'])),
      submittedBy = json['submitted_by'] as String? ?? 'Pengguna',
      createdAt = DateTime.parse(json['created_at'] as String),
      fieldName = json['field_name'] as String,
      label = json['label'] as String? ?? '',
      oldValue = json['old_value'],
      proposedValue = json['proposed_value'],
      currentValue = json['current_value'],
      oldDisplay = json['old_display'] as String?,
      proposedDisplay = json['proposed_display'] as String?,
      currentDisplay = json['current_display'] as String?,
      status = json['status'] as String? ?? CorrectionStatus.pending,
      statusLabel = json['status_label'] as String? ?? '',
      reviewNote = json['review_note'] as String? ?? '',
      stale = json['stale'] == true;

  bool get isPending => status == CorrectionStatus.pending;
}

/// Total item per status: {"pending": 3, "approved": 0, "rejected": 0}.
class ModerationStats {
  final int pending;
  final int approved;
  final int rejected;

  ModerationStats.fromJson(Map<String, dynamic> json)
    : pending = (json['pending'] as num?)?.toInt() ?? 0,
      approved = (json['approved'] as num?)?.toInt() ?? 0,
      rejected = (json['rejected'] as num?)?.toInt() ?? 0;

  int get total => pending + approved + rejected;
}

/// GET moderation/: 20 baris per halaman. Isi tab panduan ada di GET moderation/guide/ (FieldGuideEntry).
class ModerationQueue {
  static const antrean = 'antrean';
  static const semua = 'semua';
  static const panduan = 'panduan';

  final int count;
  final int page;
  final int pageSize;
  final int numPages;
  final int? nextPage;
  final int? previousPage;
  final String tab;
  final String? field; // null = semua field
  final String? status; // hanya di tab semua; null = semua status
  final List<QueueOption> tabOptions;
  final List<QueueOption> fieldOptions;
  final List<QueueOption> statusOptions; // kosong di luar tab semua
  final ModerationStats stats;
  final List<ModerationRow> results;

  ModerationQueue.fromJson(Map<String, dynamic> json)
    : count = json['count'] as int,
      page = json['page'] as int,
      pageSize = json['page_size'] as int,
      numPages = json['num_pages'] as int,
      nextPage = json['next_page'] as int?,
      previousPage = json['previous_page'] as int?,
      tab = json['tab'] as String? ?? antrean,
      field = json['field'] as String?,
      status = json['status'] as String?,
      tabOptions = _list(json['tab_options'], QueueOption.fromJson),
      fieldOptions = _list(json['field_options'], QueueOption.fromJson),
      statusOptions = _list(json['status_options'], QueueOption.fromJson),
      stats = ModerationStats.fromJson(_map(json['stats'])),
      results = _list(json['results'], ModerationRow.fromJson);
}

/// Satu baris Panduan field: {"field_name": "sodium_100g", "label": "Natrium (mg/100 g)", "kind": "Angka desimal", "rules": [...]}.
class FieldGuideEntry {
  final String fieldName;
  final String label;
  final String kind;
  final List<String> rules;

  FieldGuideEntry.fromJson(Map<String, dynamic> json)
    : fieldName = json['field_name'] as String,
      label = json['label'] as String? ?? '',
      kind = json['kind'] as String? ?? '',
      rules = _strings(json['rules']);

  /// Balasan GET moderation/guide/: {"fields": [...]}.
  static List<FieldGuideEntry> listFromJson(Map<String, dynamic> json) =>
      _list(json['fields'], FieldGuideEntry.fromJson);
}

/// Balasan `PATCH moderation/items/<pk>/`.
class ReviewResult {
  final ModerationRow
  item; // baris yang sama dengan GET item, siap menggantikan baris lama
  final int correctionId;
  final String correctionStatus; // status pengajuan sesudah tinjauan ini
  final String correctionStatusLabel;
  final Object? productValue;
  final String? productDisplay;
  final bool stale; // nilai produk sempat berubah sebelum disetujui
  final String message; // sama dengan toast web

  ReviewResult.fromJson(Map<String, dynamic> json)
    : item = ModerationRow.fromJson(_map(json['item'])),
      correctionId = _map(json['correction'])['id'] as int,
      correctionStatus =
          _map(json['correction'])['status'] as String? ??
          CorrectionStatus.pending,
      correctionStatusLabel =
          _map(json['correction'])['status_label'] as String? ?? '',
      productValue = _map(json['product'])['value'],
      productDisplay = _map(json['product'])['display'] as String?,
      stale = json['stale'] == true,
      message = json['message'] as String? ?? '';
}

/// Galat API. status 0 = tidak ada balasan (jaringan). code hanya ada di galat modul.
class ApiError implements Exception {
  final int status;
  final String? code;
  final String message;
  final Map<String, List<String>> fields;

  const ApiError(
    this.status,
    this.message, {
    this.code,
    this.fields = const {},
  });

  /// Body galat modul {"detail", "code", "fields"?} dipakai apa adanya. Bentuk lain (null, teks, atau
  /// {"detail"} bawaan DRF yang sering berbahasa Inggris) memakai pesan bawaan per status.
  factory ApiError.fromResponse(int status, Object? data) {
    if (data is Map && data['code'] is String) {
      final detail = data['detail'];
      return ApiError(
        status,
        detail is String && detail.trim().isNotEmpty
            ? detail
            : defaultMessage(status),
        code: data['code'] as String,
        fields: _fieldsFrom(data['fields']),
      );
    }
    return ApiError(status, defaultMessage(status));
  }

  static String defaultMessage(int status) => switch (status) {
    0 => 'Tidak dapat terhubung ke server. Periksa koneksi internet lalu coba lagi.',
    400 => 'Periksa kembali isian.',
    403 => 'Akses ditolak. Coba masuk ulang lalu ulangi.',
    404 => 'Data tidak ditemukan.',
    405 => 'Aksi ini tidak didukung.',
    409 => 'Data sudah berubah. Muat ulang lalu coba lagi.',
    >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
    _ => 'Terjadi kesalahan (kode $status).',
  };

  static Map<String, List<String>> _fieldsFrom(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        '${entry.key}': entry.value is List
            ? [for (final message in entry.value as List) '$message']
            : ['${entry.value}'],
    };
  }

  bool get isNetwork => status == 0;
  bool get needsLogin => code == 'authentication_required';

  /// Pesan pertama untuk satu field, atau null.
  String? fieldError(String name) {
    final messages = fields[name];
    return messages == null || messages.isEmpty ? null : messages.first;
  }

  @override
  String toString() => message;
}

const _months = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Tanggal waktu lokal: 2026-11-24 -> "24 November 2026".
String formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// Waktu relatif dengan satu satuan, seperti filter ago di web: "baru saja", "5 menit lalu", "2 jam lalu".
/// Bulan dihitung 30 hari dan tahun 365 hari.
String formatAgo(DateTime value, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(value);
  if (diff < const Duration(minutes: 1)) return 'baru saja';
  final days = diff.inDays;
  if (days >= 365) return '${days ~/ 365} tahun lalu';
  if (days >= 30) return '${days ~/ 30} bulan lalu';
  if (days >= 7) return '${days ~/ 7} minggu lalu';
  if (days >= 1) return '$days hari lalu';
  if (diff.inHours >= 1) return '${diff.inHours} jam lalu';
  return '${diff.inMinutes} menit lalu';
}
