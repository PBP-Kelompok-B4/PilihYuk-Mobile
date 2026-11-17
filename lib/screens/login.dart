import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/screens/product_catalog/product_catalog_page.dart';
import 'package:pilihyuk_mobile/screens/register.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _submit(CookieRequest request) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await request.login('$baseUrl/api/v1/auth/login/', {
        'username': _username.text.trim(),
        'password': _password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'])));
      if (request.loggedIn) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ProductCatalogPage()));
      }
    } catch (e) {
      // Server mati, tanpa internet, atau balasan bukan JSON (misalnya halaman kunci axes).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak bisa masuk sekarang. Coba lagi nanti.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = context.watch<CookieRequest>();
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk')),
      drawer: const LeftDrawer(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _username,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email atau username'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi.' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : () => _submit(request),
              child: Text(_loading ? 'Memproses...' : 'Masuk'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RegisterPage())),
              child: const Text('Belum punya akun? Daftar'),
            ),
          ],
        ),
      ),
    );
  }
}
