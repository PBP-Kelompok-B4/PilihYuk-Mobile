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
        missing = [for (final entry in json['missing']) MissingData.fromJson(entry)],
        missingCount = json['missing_count'],
        shelfCount = json['shelf_count'],
        status = json['status'],
        statusLabel = json['status_label'];

  /// "Merek · isi", bagian yang kosong dilewati. "" kalau keduanya kosong.
  String get subtitle => [brand, quantity].where((part) => part.trim().isNotEmpty).join(' · ');
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
        sortOptions = [for (final option in json['sort_options']) QueueOption.fromJson(option)],
        missingOptions = [for (final option in json['missing_options']) QueueOption.fromJson(option)],
        stats = QueueStats.fromJson(json['stats']),
        results = [for (final row in json['results']) QueueProduct.fromJson(row)];

  /// Alamat endpoint dengan query. Nilai null dan halaman 1 tidak ditulis.
  /// Contoh: uri(base, sort: 'terbaru', page: 2) -> base/api/v1/corrections/queue/?sort=terbaru&page=2
  static Uri uri(String baseUrl, {String? sort, String? missing, int page = 1}) {
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
  final text = value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')}×';
}