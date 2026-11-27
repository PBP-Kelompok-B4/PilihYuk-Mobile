import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
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
/// antrean; tiap field menjadi satu baris awal. Setelah POST mine/ berhasil, route ini diganti halaman detail
/// dan antrean menerima hasil true.
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
  bool _sending = false;
  Map<String, String> _serverErrors = const {};

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

  Future<void> _submit() async {
    if (_sending) {
      return;
    }
    _serverErrors = const {};
    final values = _values();
    _anyFilled = values.isNotEmpty;
    final valid = _formKey.currentState!.validate();
    if (!_anyFilled || !valid) {
      setState(() {
        _alert = _anyFilled ? checkInputsMessage : noneFilledMessage;
      });
      return;
    }
    setState(() {
      _alert = null;
      _sending = true;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    try {
      final correction = await CorrectionApi(context.read<CookieRequest>())
          .submit(widget.productId, values);
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CorrectionDetailPage(
            correctionId: correction.id,
            initial: correction,
            justSubmitted: true,
          ),
        ),
        result: true,
      );
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
      });
      _showError(error);
    }
  }

  /// 400: pesan per baris + kotak galat; 403: kotak galat; selain itu toast (Coba lagi bila jaringan/server).
  void _showError(ApiError error) {
    if (error.status == 403) {
      setState(() {
        _alert = error.needsLogin ? sessionEndedMessage : error.message;
      });
      return;
    }
    if (error.status == 400) {
      final named = {
        for (final row in _rows)
          if (row.field != null) row.field!,
      };
      _serverErrors = {for (final name in named) name: ?error.fieldError(name)};
      final others = [
        for (final entry in error.fields.entries)
          if (!named.contains(entry.key)) ...entry.value,
      ];
      _formKey.currentState!.validate();
      setState(() {
        _alert = [error.message, ...others].join('\n');
      });
      return;
    }
    final retry = error.isNetwork || error.status >= 500;
    showToast(
      context,
      error.message,
      success: false,
      action: retry
          ? SnackBarAction(label: 'Coba lagi', onPressed: _submit)
          : null,
    );
  }

  String? _validate(CorrectionField? field, String? text) {
    if (field == null) {
      return null;
    }
    if ((text ?? '').trim().isEmpty) {
      return _anyFilled ? null : requiredMessage;
    }
    return checkProposedValue(field, text ?? '') ??
        _serverErrors[field.fieldName];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antrean Data')),
      body: FutureBuilder<CorrectionFormData>(
        future: _form,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
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
        padding: const EdgeInsets.all(CorrectionSizes.inset),
        children: [
          const Text(
            'Antrean Data › Lengkapi Data',
            style: CorrectionText.meta,
          ),
          const SizedBox(height: CorrectionSizes.gapMd),
          const Text('Lengkapi Data', style: CorrectionText.pageTitle),
          const SizedBox(height: CorrectionSizes.gapXs),
          const Text(
            'Ajukan koreksi data produk.',
            style: CorrectionText.bodyMuted,
          ),
          const SizedBox(height: CorrectionSizes.gapLg),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: CorrectionDecorations.card,
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
                    style: CorrectionText.body,
                  ),
                ),
                const SizedBox(height: CorrectionSizes.gapMd),
                const Text(
                  'Pilih field yang ingin dikoreksi, lalu isi Usulan nilai. Tambahkan baris untuk field lain.',
                  style: CorrectionText.meta,
                ),
                const SizedBox(height: CorrectionSizes.gapSm),
                for (var i = 0; i < _rows.length; i++)
                  _rowView(data, _rows[i], i, used),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: used.length >= data.fields.length
                        ? null
                        : _addRow,
                    style: TextButton.styleFrom(
                      foregroundColor: CorrectionColors.primary,
                      minimumSize: const Size(0, CorrectionSizes.touchTarget),
                    ),
                    child: const Text('+ Tambah field lain'),
                  ),
                ),
                const SizedBox(height: CorrectionSizes.gapSm),
                const PendingNotice(),
              ],
            ),
          ),
          if (_alert case final alert?) ...[
            const SizedBox(height: CorrectionSizes.gapMd),
            _Alert(alert),
          ],
          const SizedBox(height: CorrectionSizes.gapLg),
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: CorrectionButtons.primary(),
            child: _sending
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Mengirim…'),
                    ],
                  )
                : const Text('Ajukan Koreksi'),
          ),
          const SizedBox(height: CorrectionSizes.gapXs),
          TextButton(
            onPressed: _sending ? null : () => Navigator.maybePop(context),
            style: TextButton.styleFrom(
              foregroundColor: CorrectionColors.ink,
              minimumSize: const Size.fromHeight(CorrectionSizes.touchTarget),
            ),
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
      margin: const EdgeInsets.only(bottom: CorrectionSizes.gapSm),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: CorrectionColors.border),
        borderRadius: CorrectionSizes.controlRadius,
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
            decoration: CorrectionInputs.decoration(),
            items: [
              for (final option in data.fields)
                DropdownMenuItem(
                  value: option.fieldName,
                  enabled:
                      option.fieldName == row.field ||
                      !used.contains(option.fieldName),
                  // Satu baris: label panjang dipotong "…" di layar sempit atau huruf besar.
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              setState(() {
                row.field = value;
              });
            },
          ),
          const SizedBox(height: CorrectionSizes.gapSm),
          const _Label('Nilai saat ini'),
          if (field == null)
            const _ReadOnlyBox(child: Text('—'))
          else if (!field.isKnown)
            const Align(alignment: Alignment.centerLeft, child: UnknownChip())
          else
            _ReadOnlyBox(
              child: Text(
                displayOrUnknown(field.currentDisplay),
                style: CorrectionText.value,
              ),
            ),
          const SizedBox(height: CorrectionSizes.gapSm),
          const _Label('Usulan nilai'),
          TextFormField(
            controller: row.controller,
            enabled: field != null,
            keyboardType: _keyboard(field),
            decoration: CorrectionInputs.decoration(
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: CorrectionText.label),
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
      decoration: CorrectionDecorations.field,
      child: child,
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
        decoration: const BoxDecoration(
          color: CorrectionColors.errorSoft,
          borderRadius: CorrectionSizes.controlRadius,
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
