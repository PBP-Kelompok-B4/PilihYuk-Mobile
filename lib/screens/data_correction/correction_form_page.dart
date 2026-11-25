import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

const requiredMessage = 'Isian ini wajib diisi.';
const noneFilledMessage = 'Pilih minimal satu field untuk dikoreksi.';
const checkInputsMessage = 'Periksa kembali isian yang ditandai.';
final _number = RegExp(r'^[+-]?(?:[0-9]+(?:[.,][0-9]*)?|[.,][0-9]+)$');
final _digits = RegExp(r'^[0-9]+$');

/// Pemeriksaan ringan sebelum dikirim, pesannya sama dengan validators.py di web. Aturan lengkap
/// (batas maksimum, jumlah desimal, usulan sama dengan nilai sekarang) tetap di server. null = lolos.
String? checkProposedValue(CorrectionField field, String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return requiredMessage;
  }
  if (field.isInteger) {
    final number = _digits.hasMatch(text) ? int.tryParse(text) : null;
    if (number == null || number < 1 || number > 4) {
      return 'Grup NOVA harus bilangan bulat 1 sampai 4.';
    }
  } else if (field.isNumber) {
    if (text.contains(',') && text.contains('.')) {
      return 'Tulis angka tanpa pemisah ribuan, misalnya 1234,5 (bukan 1.234,5).';
    }
    if (!_number.hasMatch(text)) {
      return 'Masukkan angka, misalnya 7,5.';
    }
    if (text.startsWith('-') && text.contains(RegExp('[1-9]'))) {
      return 'Nilai tidak boleh negatif.';
    }
  }
  return null;
}

/// Form Lengkapi Data untuk satu produk aktif (GET products/{id}/form/). focus = field kosong dari kartu
/// antrean; tiap field menjadi satu baris awal.
class CorrectionFormPage extends StatefulWidget {
  const CorrectionFormPage({
    super.key,
    required this.productId,
    this.focus = const [],
  });

  final int productId;
  final List<String> focus;

  @override
  State<CorrectionFormPage> createState() => _CorrectionFormPageState();
}

class _FieldRow {
  _FieldRow(this.field);

  String? field;
  final controller = TextEditingController();
}

class _CorrectionFormPageState extends State<CorrectionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _rows = <_FieldRow>[];
  late Future<CorrectionFormData> _form;
  String? _alert;
  bool _anyFilled = true;

  @override
  void initState() {
    super.initState();
    _form = _load();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  Future<CorrectionFormData> _load() async {
    final api = CorrectionApi(context.read<CookieRequest>());
    final data = await api.fetchForm(widget.productId, focus: widget.focus);
    if (_rows.isEmpty) {
      _rows.addAll([for (final name in data.focus) _FieldRow(name)]);
      if (_rows.isEmpty) {
        _rows.add(_FieldRow(null));
      }
    }
    return data;
  }

  void _reload() {
    setState(() {
      _form = _load();
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(_FieldRow(null));
    });
  }

  void _removeRow(_FieldRow row) {
    setState(() {
      _rows.remove(row);
    });
    // TextFormField-nya baru dilepas di frame berikutnya.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => row.controller.dispose(),
    );
  }

  /// field_name -> isian, hanya baris yang berisi. Baris kosong tidak dikirim (seperti di web).
  Map<String, String> _values() => {
    for (final row in _rows)
      if (row.field != null && row.controller.text.trim().isNotEmpty)
        row.field!: row.controller.text.trim(),
  };

  void _submit() {
    _anyFilled = _values().isNotEmpty;
    final valid = _formKey.currentState!.validate();
    setState(() {
      _alert = !_anyFilled
          ? noneFilledMessage
          : (valid ? null : checkInputsMessage);
    });
    if (!_anyFilled || !valid) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Pengiriman menyusul.')));
  }

  String? _validate(CorrectionField? field, String? text) {
    if (field == null) {
      return null;
    }
    if ((text ?? '').trim().isEmpty) {
      return _anyFilled ? null : requiredMessage;
    }
    return checkProposedValue(field, text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antrean Data')),
      body: FutureBuilder<CorrectionFormData>(
        future: _form,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = snapshot.error;
          if (error != null) {
            return ErrorView(
              message: error is ApiError ? error.message : 'Gagal memuat form.',
              onRetry: _reload,
            );
          }
          return _formView(snapshot.data!);
        },
      ),
    );
  }

  Widget _formView(CorrectionFormData data) {
    final used = {
      for (final row in _rows)
        if (row.field != null) row.field!,
    };
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Antrean Data › Lengkapi Data',
            style: TextStyle(color: CorrectionColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text(
            'Lengkapi Data',
            style: TextStyle(
              color: CorrectionColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajukan koreksi data produk.',
            style: TextStyle(color: CorrectionColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CorrectionColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CorrectionColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Label('Produk'),
                _ReadOnlyBox(
                  child: Text(
                    [
                      data.product.displayName,
                      data.product.subtitle,
                    ].where((part) => part.isNotEmpty).join(' · '),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pilih field yang ingin dikoreksi, lalu isi Usulan nilai. Tambahkan baris untuk field lain.',
                  style: TextStyle(color: CorrectionColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _rows.length; i++)
                  _rowView(data, _rows[i], i, used),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: used.length >= data.fields.length
                        ? null
                        : _addRow,
                    child: const Text('+ Tambah field lain'),
                  ),
                ),
                const SizedBox(height: 12),
                const _Notice(),
              ],
            ),
          ),
          if (_alert != null) ...[const SizedBox(height: 16), _Alert(_alert!)],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: CorrectionColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Ajukan Koreksi'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.maybePop(context),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Widget _rowView(
    CorrectionFormData data,
    _FieldRow row,
    int index,
    Set<String> used,
  ) {
    final field = row.field == null ? null : data.field(row.field!);
    return Container(
      key: ValueKey('correction-row-$index'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: CorrectionColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: _Label('Field')),
              if (_rows.length > 1)
                IconButton(
                  tooltip: 'Hapus baris ini',
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeRow(row),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: ObjectKey(row),
            initialValue: row.field,
            isExpanded: true,
            hint: const Text('Pilih field…'),
            decoration: _decoration(),
            items: [
              for (final option in data.fields)
                DropdownMenuItem(
                  value: option.fieldName,
                  enabled:
                      option.fieldName == row.field ||
                      !used.contains(option.fieldName),
                  child: Text(option.label),
                ),
            ],
            onChanged: (value) {
              setState(() {
                row.field = value;
              });
            },
          ),
          const SizedBox(height: 12),
          const _Label('Nilai saat ini'),
          if (field == null)
            const _ReadOnlyBox(child: Text('—'))
          else if (!field.isKnown)
            const Align(alignment: Alignment.centerLeft, child: UnknownChip())
          else
            _ReadOnlyBox(
              child: Text(
                displayOrUnknown(field.currentDisplay),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 12),
          const _Label('Usulan nilai'),
          TextFormField(
            controller: row.controller,
            enabled: field != null,
            keyboardType: _keyboard(field),
            decoration: _decoration(
              hint: field == null ? 'Pilih field dulu' : null,
              helper: field?.helpText,
            ),
            validator: (text) => _validate(field, text),
          ),
        ],
      ),
    );
  }
}

TextInputType _keyboard(CorrectionField? field) {
  if (field != null && field.isInteger) {
    return TextInputType.number;
  }
  if (field != null && field.isNumber) {
    return const TextInputType.numberWithOptions(decimal: true);
  }
  return TextInputType.text;
}

InputDecoration _decoration({String? hint, String? helper}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    errorMaxLines: 3,
    isDense: true,
    filled: true,
    fillColor: CorrectionColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: border(CorrectionColors.strong),
    disabledBorder: border(CorrectionColors.border),
    focusedBorder: border(CorrectionColors.primary, 1.5),
    errorBorder: border(CorrectionColors.error),
    focusedErrorBorder: border(CorrectionColors.error, 1.5),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: CorrectionColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReadOnlyBox extends StatelessWidget {
  const _ReadOnlyBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CorrectionColors.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CorrectionColors.warningSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text.rich(
        TextSpan(
          style: TextStyle(color: CorrectionColors.warning, fontSize: 13),
          children: [
            TextSpan(
              text: 'Usulan belum disetujui. ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: 'Data produk tetap seperti sekarang sampai pengajuan ditinjau kurator.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CorrectionColors.errorSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: CorrectionColors.error,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
