# PilihYuk Mobile

> Bandingkan gizi dan jejak lingkungan sebelum pilih satu.

Proyek Akhir Semester, Pemrograman Berbasis Platform (CSGE602022), Fakultas Ilmu Komputer, Universitas Indonesia, Semester Gasal 2026/2027. Kelompok 4, Kelas B, sub-tema Sustainable Food & Diet.

- Situs web (PWS): https://ahmad-rizki53-pilihyuk.pws.cs.ui.ac.id/
- Repositori situs web: https://github.com/PBP-Kelompok-B4/PilihYuk
- Desain Figma: https://www.figma.com/design/6CwhelVNc1lJ9XWB4OnYlc/Wireframe?m=auto&t=CVl65mv1cAQ71x4E-6
- APK: menyusul

## Anggota Kelompok

| No | Nama | NPM | Modul |
|----|------|-----|-------|
| 1 | Yasmin | 2506606124 | Katalog Produk |
| 2 | Ahmad Rizki Daffaa | 2506543640 | Shelf dan Tabel Pembanding, Akun |
| 3 | Rafael Arlen Wijanarko | 2506613514 | Rekomendasi Komunitas |
| 4 | Muhammad Rayyan Basalamah | 2406496372 | Antrean Data |
| 5 | Jonathan Sebastian Sindhu | 2506619650 | Preferensi Nutrisi dan Riwayat Keputusan |

## Deskripsi

PilihYuk Mobile adalah versi aplikasi ponsel dari situs web PilihYuk. Aplikasi ini menaruh gizi dan dampak lingkungan produk makanan dan minuman dalam satu tabel, supaya pengguna bisa memilih satu di antaranya saat berdiri di depan rak.

Unit kerjanya adalah shelf: kumpulan produk yang saling menggantikan karena pengguna hanya akan mengambil satu. Pengguna membuat shelf, memakainya lagi, dan halaman shelf langsung berupa tabel pembanding. Data produk berasal dari [Open Food Facts](https://world.openfoodfacts.org/).

## Modul dan Pembagian Kerja

Setiap anggota mengerjakan endpoint Django REST Framework untuk modulnya di repositori situs web, lalu halaman Flutter yang memakai endpoint tersebut di repositori ini.

| Modul | Pengerjaan | Halaman Flutter | Endpoint API |
|-------|------------|-----------------|--------------|
| Katalog Produk | Yasmin | Daftar dan pencarian produk, detail produk, lookup barcode, tambah produk manual, riwayat lihat | `/api/v1/products/` |
| Shelf dan Tabel Pembanding | Ahmad Rizki Daffaa | Daftar shelf publik dan milik sendiri, buat, ubah dan hapus shelf, tambah dan keluarkan produk, tabel pembanding | `/api/v1/shelves/` |
| Rekomendasi Komunitas | Rafael Arlen Wijanarko | Daftar rekomendasi dengan filter dan urutan, detail, usulan, suara, ubah dan hapus | `/api/v1/recommendations/` |
| Antrean Data | Muhammad Rayyan Basalamah | Antrean kontribusi, ajukan koreksi, koreksi saya, antrean kurator dan tinjauan | `/api/v1/corrections/` |
| Preferensi Nutrisi dan Riwayat Keputusan | Jonathan Sebastian Sindhu | Atur preferensi, pratinjau urutan, riwayat keputusan | `/api/v1/preferences/` |
| Akun (bersama) | Ahmad Rizki Daffaa | Masuk, daftar, keluar, drawer navigasi | `/api/v1/auth/` |

## Peran Pengguna

| Peran | Yang bisa dilakukan |
|-------|---------------------|
| Pengunjung | Menelusuri katalog dan shelf publik, melihat tabel pembanding, dan membaca rekomendasi |
| Pengguna terdaftar | Semua di atas, ditambah mengelola shelf, membuat rekomendasi dan memberi suara, mengajukan koreksi data, mengatur preferensi nutrisi, dan mencatat keputusan |
| Kurator data | Meninjau pengajuan koreksi (setujui atau tolak) dan menyunting produk |

## Alur Integrasi Data

Semua data tetap tersimpan di situs web Django di PWS. Aplikasi ini tidak menyimpan data statis.

1. Setiap modul di situs web punya `serializers.py`, `api_views.py` dan `api_urls.py` (Django REST Framework). Semua endpoint ada di bawah `/api/v1/`.
2. Aplikasi memakai `CookieRequest` dari paket [`pbp_django_auth`](https://pub.dev/packages/pbp_django_auth), yang dibagikan ke semua halaman lewat `Provider`.
3. Saat masuk, aplikasi mengirim email dan password ke `/api/v1/auth/login/`. Django memeriksa akun dengan form yang sama dengan situs web (termasuk batas percobaan gagal), lalu membuat sesi. `CookieRequest` menyimpan cookie sesi dan mengirimkannya di setiap permintaan berikutnya.
4. Halaman modul memanggil endpoint secara asinkron: membaca dengan `request.get`, dan menulis (POST, PUT, PATCH, DELETE) dengan `sendJson` dari `lib/api.dart`, yang menambahkan token CSRF dari cookie login. JSON balasan diubah menjadi model Dart, lalu ditampilkan.
5. Perubahan dari aplikasi langsung tersimpan di basis data PWS, jadi situs web dan aplikasi selalu menampilkan data yang sama.

## Menjalankan Aplikasi

```bash
flutter pub get
flutter run
```

Secara bawaan aplikasi memanggil situs web di PWS. Untuk server Django lokal dari emulator Android:

```bash
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000
```

## Alur Kerja Git

- `main`: versi stabil, sumber APK.
- `dev`: tempat semua modul digabung lewat pull request.
- Branch per modul: `product_catalog`, `shelves`, `recommendations`, `data_correction`, `preferences`. Buat dari `main`, lalu buka pull request ke `dev`.
- Setiap anggota hanya mengubah `lib/screens/<modul>/` dan `lib/models/<modul>.dart` miliknya. `main.dart`, `config.dart` dan `widgets/left_drawer.dart` dipegang Ahmad Rizki Daffaa.
