import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_form_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';
import 'package:pilihyuk_mobile/screens/login.dart';
import 'package:pilihyuk_mobile/screens/register.dart';

const loginRequiredTitle = 'Masuk untuk menggunakan fitur ini.';
const loginRequiredMessage =
    'Ajukan koreksi dan lihat Pengajuan Saya membutuhkan akun.';

/// Nama field yang bisa dikoreksi, sama dengan CORRECTABLE_FIELDS di web (data_correction/constants.py).
/// Teks: product_name, brand, quantity, category, origin. Angka: nova_group (1 sampai 4), energy_kcal_100g
/// (kkal), proteins_100g, fat_100g, saturated_fat_100g, carbohydrates_100g, sugars_100g, fiber_100g (gram),
/// dan sodium_100g (diisi dalam mg). Semua angka gizi per 100 g.
const correctableFields = [
  'product_name',
  'brand',
  'quantity',
  'category',
  'origin',
  'nova_group',
  'energy_kcal_100g',
  'proteins_100g',
  'fat_100g',
  'saturated_fat_100g',
  'carbohydrates_100g',
  'sugars_100g',
  'fiber_100g',
  'sodium_100g',
];

/// Pintu masuk form Lengkapi Data untuk halaman anggota lain, cukup satu baris. Gerbang login (GET me/, lalu
/// sheet "Masuk untuk menggunakan fitur ini." bila belum masuk), form, dan halaman sukses diurus modul ini;
/// tombol kembali di halaman modul pulang ke halaman pemanggil. Modul ini tidak mengimpor halaman pemanggil.
///
/// - productId: id Product di server, sama dengan id di katalog.
/// - fields: baris awal form, nama dari [correctableFields]. Kosong berarti satu baris kosong. Nama lain dan
///   nama ganda diabaikan, seperti ?field= di web.
///
/// Hasil: true bila pengajuan terkirim (saat itu halaman sukses sedang tampil di atas halaman pemanggil);
/// false bila pengguna tidak jadi masuk atau menutup form tanpa mengirim. Produk yang tidak ada atau nonaktif
/// ditangani form sendiri (pesan galat dan Coba lagi).
///
/// Tombol di detail produk (Yasmin):
/// ```dart
/// OutlinedButton(
///   onPressed: () => openCorrectionForm(context, productId: product.id),
///   child: const Text('Bantu lengkapi data'),
/// )
/// ```
///
/// Sel "Tidak diketahui" di tabel pembanding shelf (Daffaa); fields berisi field baris itu:
/// ```dart
/// TextButton(
///   onPressed: () => openCorrectionForm(context, productId: productId, fields: ['sodium_100g']),
///   child: const Text('Tidak diketahui'),
/// )
/// ```
Future<bool> openCorrectionForm(
  BuildContext context, {
  required int productId,
  List<String> fields = const [],
}) async {
  final viewer = await loadViewer(context.read<CookieRequest>());
  if (!context.mounted) {
    return false;
  }
  if (!await ensureLoggedIn(context, viewer: viewer)) {
    return false;
  }
  if (!context.mounted) {
    return false;
  }
  // toSet membuang nama ganda tanpa mengubah urutan; nama di luar daftar dibuang.
  final focus = [
    for (final name in fields.toSet())
      if (correctableFields.contains(name)) name,
  ];
  // Setelah POST berhasil, form menggantikan dirinya dengan halaman sukses lewat pushReplacement(result: true).
  final result = await pushModulePage<Object?>(
    context,
    'form',
    CorrectionFormPage(productId: productId, focus: focus),
  );
  return result == true;
}

/// Awalan nama route halaman modul. Antrean sendiri dibuka drawer tanpa nama, jadi "kembali ke antrean"
/// berarti menutup semua route yang namanya berawalan ini.
const moduleRoutePrefix = '/antrean-data/';

/// Route halaman modul, mis. moduleRoute('form', page) bernama '/antrean-data/form'.
MaterialPageRoute<T> moduleRoute<T>(String name, Widget page) =>
    MaterialPageRoute<T>(
      settings: RouteSettings(name: '$moduleRoutePrefix$name'),
      builder: (_) => page,
    );

/// Navigator.push (bukan pushReplacement), jadi tombol kembali selalu kembali ke halaman pemanggil.
Future<T?> pushModulePage<T>(BuildContext context, String name, Widget page) =>
    Navigator.push<T>(context, moduleRoute<T>(name, page));

bool isModuleRoute(Route<dynamic> route) =>
    route.settings.name?.startsWith(moduleRoutePrefix) ?? false;

/// Menutup halaman ini dan semua halaman modul di bawahnya sampai antrean (popUntil), tanpa menumpuk
/// antrean baru. Halaman ini sendiri boleh tanpa nama, mis. detail sukses yang menggantikan form.
void backToQueue(BuildContext context) {
  final current = ModalRoute.of(context);
  Navigator.popUntil(
    context,
    (route) => route.isFirst || (route != current && !isModuleRoute(route)),
  );
}

/// Hasil GET me/, atau null bila gagal. me/ bilang belum masuk padahal request.loggedIn true (sesi habis):
/// logout lokal supaya drawer kembali menampilkan "Masuk" (KEPUTUSAN F.a).
Future<Viewer?> loadViewer(CookieRequest request) async {
  try {
    // init (penyimpanan lokal) ditunggu di luar batas waktu 20 detik CorrectionApi, yang hanya untuk jaringan.
    await request.init();
    final viewer = await CorrectionApi(request).me();
    if (!viewer.loggedIn && request.loggedIn) {
      await signOut(request);
    }
    return viewer;
  } on Exception {
    return null;
  }
}

/// Logout pbp_django_auth, sama dengan tombol Keluar di drawer.
Future<void> signOut(CookieRequest request) async {
  try {
    await request.logout('$baseUrl/api/v1/auth/logout/');
  } on Exception {
    // Server tidak terjangkau: status login tetap ditentukan me/ berikutnya.
  }
}

/// 403 authentication_required di tengah jalan (KEPUTUSAN F.a): logout lokal, lalu sheet login berpesan sesi
/// habis di atas halaman yang sedang tampil. true bila pengguna sudah masuk lagi.
Future<bool> handleSessionEnded(BuildContext context) async {
  await signOut(context.read<CookieRequest>());
  if (!context.mounted) {
    return false;
  }
  return showLoginSheet(context, message: sessionEndedMessage);
}

/// Gerbang login (pola ensureLoggedIn Tutorial 10). viewer = hasil me/ terakhir; null (me/ gagal) memakai
/// request.loggedIn. Belum masuk -> sheet login. true bila sudah masuk, termasuk setelah masuk lewat sheet.
Future<bool> ensureLoggedIn(BuildContext context, {Viewer? viewer}) async {
  if (viewer?.loggedIn ?? context.read<CookieRequest>().loggedIn) {
    return true;
  }
  return showLoginSheet(context);
}

enum _AuthChoice { login, register }

/// Sheet "Masuk untuk menggunakan fitur ini." (Figma 285:8328). true bila pengguna sudah masuk saat kembali.
Future<bool> showLoginSheet(
  BuildContext context, {
  String message = loginRequiredMessage,
}) async {
  final choice = await showModalBottomSheet<_AuthChoice>(
    context: context,
    backgroundColor: CorrectionColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _LoginSheet(message: message),
  );
  if (choice == null) {
    return false;
  }
  if (!context.mounted) {
    return false;
  }
  return _openAuthPage(
    context,
    choice == _AuthChoice.login ? const LoginPage() : const RegisterPage(),
  );
}

/// Membuka LoginPage atau RegisterPage, lalu kembali ke halaman yang tadi tampil. KEPUTUSAN TAHAP 0 (c):
/// LoginPage mengganti dirinya dengan Katalog setelah berhasil (hasil null), jadi Katalog itu ditutup.
Future<bool> _openAuthPage(BuildContext context, Widget page) async {
  final navigator = Navigator.of(context);
  final request = context.read<CookieRequest>();
  final result = await navigator.push<Object?>(
    MaterialPageRoute<Object?>(builder: (_) => page),
  );
  if (!request.loggedIn) {
    return false;
  }
  if (result == null) {
    navigator.pop();
  }
  return true;
}

class _LoginSheet extends StatelessWidget {
  const _LoginSheet({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: CorrectionColors.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: CorrectionColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              loginRequiredTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CorrectionColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CorrectionColors.muted,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _AuthChoice.login),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: CorrectionColors.primary,
                      foregroundColor: Colors.white,
                      shape: shape,
                    ),
                    icon: const Icon(Icons.login),
                    label: const Text('Masuk'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pop(context, _AuthChoice.register),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        foregroundColor: CorrectionColors.ink,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        shape: shape,
                      ),
                      child: const Text('Daftar'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
