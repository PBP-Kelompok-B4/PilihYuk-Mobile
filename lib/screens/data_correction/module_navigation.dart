import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';
import 'package:pilihyuk_mobile/screens/login.dart';
import 'package:pilihyuk_mobile/screens/register.dart';

const loginRequiredTitle = 'Masuk untuk menggunakan fitur ini.';
const loginRequiredMessage =
    'Ajukan koreksi dan lihat Pengajuan Saya membutuhkan akun.';

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

/// KEPUTUSAN TAHAP 0 (c): LoginPage selalu pindah ke Katalog setelah berhasil. Jadi begitu halaman itu
/// selesai dan pengguna sudah masuk, route di atas halaman pemanggil ditutup (popUntil).
Future<bool> _openAuthPage(BuildContext context, Widget page) async {
  final navigator = Navigator.of(context);
  final here = ModalRoute.of(context);
  final request = context.read<CookieRequest>();
  await navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  if (!request.loggedIn) {
    return false;
  }
  navigator.popUntil((route) => route == here || route.isFirst);
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
