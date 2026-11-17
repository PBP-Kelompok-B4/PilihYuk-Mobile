import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fields = {
    'display_name': ('Nama tampilan', TextEditingController()),
    'email': ('Email', TextEditingController()),
    'password1': ('Password', TextEditingController()),
    'password2': ('Konfirmasi password', TextEditingController()),
  };
  Map<String, dynamic> _errors = {};
  bool _loading = false;

  Future<void> _submit(CookieRequest request) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await request.post('$baseUrl/api/v1/auth/register/',
          {for (final e in _fields.entries) e.key: e.value.$2.text});
      if (!mounted) return;
      if (response['status'] == true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Akun berhasil dibuat. Silakan masuk.')));
        Navigator.pop(context);
      } else {
        setState(() => _errors = Map<String, dynamic>.from(response['errors'] ?? {}));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak bisa mendaftar sekarang. Coba lagi nanti.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.$2.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = context.watch<CookieRequest>();
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final MapEntry(key: name, value: (label, controller)) in _fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: controller,
                  obscureText: name.startsWith('password'),
                  decoration: InputDecoration(
                    labelText: label,
                    // Pesan validasi dari form Django, misalnya email sudah terdaftar.
                    errorText: (_errors[name] as List?)?.join(' '),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi.' : null,
                ),
              ),
            if (_errors['__all__'] != null)
              Text((_errors['__all__'] as List).join(' '),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : () => _submit(request),
              child: Text(_loading ? 'Memproses...' : 'Daftar'),
            ),
          ],
        ),
      ),
    );
  }
}
