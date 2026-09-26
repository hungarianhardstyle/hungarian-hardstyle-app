import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/i18n/tr.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_text.dart';

/// A WordPress admin-művelet a natív szerkesztőhöz (betöltés + mentés).
///
/// **Azért külön provider, hogy a képernyő Firebase nélkül tesztelhető legyen:**
/// a `CommunityService` példányosítása a Firestore-t is felépíti, ezért a teszt
/// nem tudja `overrideWithValue`-val helyettesíteni. Ez a szűk szelet viszont
/// könnyen felülírható, és pontosan azt fedi le, amit a képernyő használ.
final adminResourceRequestProvider =
    Provider<
      Future<dynamic> Function(
        String path, {
        String method,
        Map<String, dynamic>? body,
      })
    >((ref) {
      return (
        String path, {
        String method = 'GET',
        Map<String, dynamic>? body,
      }) => ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(path: path, method: method, body: body);
    });

/// ÚJ vagy MEGLÉVŐ kérdőív / nyereményjáték / kvíz szerkesztése a natív adminból.
///
/// **MIÉRT született:** a tulajdonos jelezte, hogy a natív Vezérlőközpontból
/// ezeket csak **megnézni** lehetett, **létrehozni** nem — a szerver ugyanis
/// kizárólag az esemény/DJ/szervező/release típusokhoz adott mezőket. A plugin
/// 2.5.7 ezt kinyitotta (`includes/admin-create.php`), ez a képernyő pedig
/// **ugyanazt az űrlapot** használja létrehozáshoz és szerkesztéshez: a mezőket
/// a szerver írja le (`action=resource`), ezért a kettő nem tud szétszakadni.
///
/// A mezőtípusok: `text`, `textarea`, `int`, `bool`, `url`, `email`, `select`,
/// `text_list` (2–6 válasz), `questions` (kérdés + 2–6 válasz + helyes válasz).
class AdminResourceEditorScreen extends ConsumerStatefulWidget {
  const AdminResourceEditorScreen({
    super.key,
    required this.type,
    this.id = 0,
    this.typeLabel = '',
  });

  /// A WordPress bejegyzéstípus (`huhs_poll`, `huhs_prize`, `huhs_game`).
  final String type;

  /// 0 = létrehozás, egyébként a szerkesztendő bejegyzés azonosítója.
  final int id;

  /// A címhez (pl. „Kérdőív”).
  final String typeLabel;

  @override
  ConsumerState<AdminResourceEditorScreen> createState() =>
      _AdminResourceEditorScreenState();
}

/// Egy válaszlehetőség-sor a szerkesztőben.
class _ListRow {
  _ListRow(String value) : controller = TextEditingController(text: value);
  final TextEditingController controller;
  void dispose() => controller.dispose();
}

/// Egy kérdés a kvíz-szerkesztőben.
class _QuestionRow {
  _QuestionRow({
    String prompt = '',
    List<String> options = const [],
    this.correct = -1,
  }) : prompt = TextEditingController(text: prompt),
       options = (options.isEmpty ? <String>['', ''] : options)
           .map((value) => _ListRow(value))
           .toList();

  final TextEditingController prompt;
  final List<_ListRow> options;
  int correct;

  void dispose() {
    prompt.dispose();
    for (final option in options) {
      option.dispose();
    }
  }

  Map<String, dynamic> toJson() => {
    'prompt': prompt.text.trim(),
    'options': options
        .map((option) => option.controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList(),
    'correct': correct,
  };
}

class _AdminResourceEditorScreenState
    extends ConsumerState<AdminResourceEditorScreen> {
  final _title = TextEditingController();
  final _controllers = <String, TextEditingController>{};
  final _checks = <String, bool>{};
  final _lists = <String, List<_ListRow>>{};
  final _questions = <_QuestionRow>[];
  final _selects = <String, String>{};

  List<Map<String, dynamic>> _fields = const [];
  String _status = 'publish';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.id == 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final rows in _lists.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  String _label() => widget.typeLabel.isNotEmpty ? widget.typeLabel : 'elem';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(adminResourceRequestProvider)(
        '/huhs/v1/admin?action=resource&type=${widget.type}&id=${widget.id}',
      );
      if (!mounted) return;
      final data = Map<String, dynamic>.from(response as Map);
      final fields = (data['fields'] as List? ?? const [])
          .whereType<Map>()
          .map((field) => Map<String, dynamic>.from(field))
          .toList();
      _title.text = '${data['title'] ?? ''}';
      // ÚJ elemnél a szerver egy „draft” helyőrzőt ad vissza a létrehozó válaszban;
      // ilyenkor a feltételezett állapot a **közzétett**, mert a tulajdonos azért
      // hoz létre kvízt/nyereményjátékot, hogy az megjelenjen. (A teszt fogta meg,
      // hogy a helyőrző különben csendben piszkozatként mentette volna el.)
      _status = !_isNew && '${data['status'] ?? ''}' == 'draft' ? 'draft' : 'publish';
      for (final field in fields) {
        final key = '${field['key'] ?? ''}';
        if (key.isEmpty) continue;
        final value = field['value'];
        switch ('${field['type'] ?? 'text'}') {
          case 'bool':
            _checks[key] = value == true || value == 1 || value == '1';
          case 'select':
            final options = field['options'];
            final first = options is List && options.isNotEmpty
                ? '${(options.first as Map)['value'] ?? ''}'
                : '';
            _selects[key] = '${value ?? ''}'.isEmpty ? first : '${value ?? ''}';
          case 'text_list':
            final stored = _decodeList(value);
            // A sorok számát a mező `min` értéke adja (kérdőív: 2, nyereményjáték:
            // 3) — így a szerkesztő eleve annyi sort mutat, amennyi kell.
            final minimum = (field['min'] as num?)?.toInt() ?? 2;
            final count = stored.isEmpty
                ? (minimum < 2 ? 2 : minimum)
                : stored.length;
            _lists[key] = List<_ListRow>.generate(
              count,
              (index) => _ListRow(index < stored.length ? stored[index] : ''),
            );
          case 'questions':
            final stored = _decodeQuestions(value);
            _questions
              ..clear()
              ..addAll(stored.isEmpty ? [_QuestionRow()] : stored);
          default:
            _controllers[key] = TextEditingController(text: _plain(value));
        }
      }
      setState(() {
        _fields = fields;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(error);
      });
    }
  }

  /// A tárolt érték emberi szöveggé alakítása (a JSON-tömböket is kezeli).
  String _plain(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    return '$value';
  }

  List<String> _decodeList(Object? value) {
    if (value is List) {
      return value.map((item) => '$item').where((item) => item.isNotEmpty).toList();
    }
    final raw = _plain(value).trim();
    if (raw.isEmpty) return const [];
    if (raw.startsWith('[')) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          return parsed.map((item) => '$item').toList();
        }
      } catch (_) {
        // Nem érvényes JSON: marad a soronkénti bontás.
      }
    }
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<_QuestionRow> _decodeQuestions(Object? value) {
    final raw = _plain(value);
    if (raw.trim().isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return const [];
      return parsed.whereType<Map>().map((item) {
        final options = (item['options'] as List? ?? const [])
            .map((option) => '$option')
            .where((option) => option.isNotEmpty)
            .toList();
        return _QuestionRow(
          prompt: '${item['prompt'] ?? ''}',
          options: options.isEmpty ? <String>['', ''] : options,
          correct: item['correct'] is int
              ? item['correct'] as int
              : int.tryParse('${item['correct']}') ?? -1,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _collectMeta() {
    final meta = <String, dynamic>{};
    for (final field in _fields) {
      final key = '${field['key'] ?? ''}';
      if (key.isEmpty) continue;
      switch ('${field['type'] ?? 'text'}') {
        case 'bool':
          meta[key] = _checks[key] ?? false;
        case 'select':
          meta[key] = _selects[key] ?? '';
        case 'text_list':
          meta[key] = (_lists[key] ?? const <_ListRow>[])
              .map((row) => row.controller.text.trim())
              .where((value) => value.isNotEmpty)
              .toList();
        case 'questions':
          meta[key] = _questions.map((question) => question.toJson()).toList();
        default:
          meta[key] = _controllers[key]?.text.trim() ?? '';
      }
    }
    return meta;
  }

  /// Helyi ellenőrzés — ugyanaz, mint amit a szerver is kér, csak azonnal.
  String _validateLocally() {
    for (final field in _fields) {
      final key = '${field['key'] ?? ''}';
      final type = '${field['type'] ?? 'text'}';
      if (type == 'text_list') {
        final values = (_lists[key] ?? const <_ListRow>[])
            .map((row) => row.controller.text.trim())
            .where((value) => value.isNotEmpty)
            .toList();
        final min = (field['min'] as num?)?.toInt() ?? 1;
        final max = (field['max'] as num?)?.toInt() ?? 0;
        if (values.length < min) {
          return AppStrings.trArgs('{label}: legalább {min} érték kell.', {'label': '${field['label'] ?? key}', 'min': '$min'});
        }
        if (max > 0 && values.length > max) {
          return AppStrings.trArgs('{label}: legfeljebb {max} érték adható.', {'label': '${field['label'] ?? key}', 'max': '$max'});
        }
      }
      if (type == 'questions') {
        if (_questions.isEmpty) return AppStrings.tr('Legalább 1 kérdés kell.');
        for (var index = 0; index < _questions.length; index++) {
          final question = _questions[index];
          final row = index + 1;
          if (question.prompt.text.trim().isEmpty) {
            return AppStrings.trArgs('A(z) {row}. kérdés szövege üres.', {'row': '$row'});
          }
          final options = question.options
              .map((option) => option.controller.text.trim())
              .where((value) => value.isNotEmpty)
              .toList();
          if (options.length < 2 || options.length > 6) {
            return AppStrings.trArgs('A(z) {row}. kérdéshez 2–6 válaszlehetőség kell.', {'row': '$row'});
          }
          if (question.correct < 0 || question.correct >= options.length) {
            return AppStrings.trArgs('A(z) {row}. kérdésnél jelöld meg a helyes választ.', {'row': '$row'});
          }
        }
      }
    }
    return '';
  }

  Future<void> _save() async {
    final localError = _validateLocally();
    if (localError.isNotEmpty) {
      _message(localError);
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await ref.read(adminResourceRequestProvider)(
        '/huhs/v1/admin',
        method: 'POST',
        body: {
          'action': 'save_resource',
          'id': widget.id,
          'type': widget.type,
          'status': _status,
          'title': _title.text.trim(),
          'meta': _collectMeta(),
        },
      );
      if (!mounted) return;
      final created = response is Map && response['created'] == true;
      Navigator.of(context).pop(true);
      _message(
        created
            ? AppStrings.trArgs('A(z) {label} létrehozva.', {'label': _label()})
            : AppStrings.trArgs('A(z) {label} mentve.', {'label': _label()}),
      );
    } catch (error) {
      if (!mounted) return;
      _message(AppStrings.trArgs('A mentés nem sikerült: {error}', {'error': userFacingError(error)}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? trArgs(context, 'Új {label}', {'label': _label().toLowerCase()})
              : trArgs(context, '{label} szerkesztése', {'label': _label()}),
        ),
        actions: [
          if (!_loading && _error == null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? tr(context, 'Mentés…') : tr(context, 'Mentés')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isNew)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        trArgs(
                          context,
                          'A(z) {label} a mentés után azonnal megjelenik az appban (kivéve, ha piszkozatot választasz).',
                          {'label': _label().toLowerCase()},
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                for (final field in _fields) _field(field),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'publish', label: AppText('Közzétéve')),
                    ButtonSegment(value: 'draft', label: AppText('Piszkozat')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (selection) =>
                      setState(() => _status = selection.first),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isNew ? tr(context, 'Létrehozás') : tr(context, 'Mentés')),
                ),
              ],
            ),
    );
  }

  Widget _field(Map<String, dynamic> field) {
    final key = '${field['key'] ?? ''}';
    final label = '${field['label'] ?? key}';
    final type = '${field['type'] ?? 'text'}';
    switch (type) {
      case 'bool':
        return SwitchListTile(
          key: Key('admin-field-$key'),
          value: _checks[key] ?? false,
          title: Text(label),
          onChanged: (value) => setState(() => _checks[key] = value),
        );
      case 'select':
        final options = (field['options'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (option) => DropdownMenuItem<String>(
                value: '${option['value'] ?? ''}',
                child: Text('${option['label'] ?? option['value'] ?? ''}'),
              ),
            )
            .toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: Key('admin-field-$key'),
            initialValue: _selects[key],
            decoration: InputDecoration(labelText: label),
            items: options,
            onChanged: (value) => setState(() => _selects[key] = value ?? ''),
          ),
        );
      case 'text_list':
        return _listField(field);
      case 'questions':
        return _questionsField(field);
      case 'textarea':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: Key('admin-field-$key'),
            controller: _controllers[key],
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(labelText: label),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: Key('admin-field-$key'),
            controller: _controllers[key],
            keyboardType: type == 'int'
                ? const TextInputType.numberWithOptions(signed: false)
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: label,
              helperText: type == 'int' ? tr(context, 'Szám') : null,
            ),
          ),
        );
    }
  }

  Widget _listField(Map<String, dynamic> field) {
    final key = '${field['key'] ?? ''}';
    final rows = _lists.putIfAbsent(key, () => [_ListRow(''), _ListRow('')]);
    final max = (field['max'] as num?)?.toInt() ?? 0;
    return Card(
      key: Key('admin-field-$key'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${field['label'] ?? key}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < rows.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('admin-list-$key-$index'),
                        controller: rows[index].controller,
                        decoration: InputDecoration(
                          labelText: trArgs(context, '{n}. lehetőség', {
                            'n': '${index + 1}',
                          }),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Sor törlése'),
                      onPressed: rows.length <= 2
                          ? null
                          : () => setState(() => rows.removeAt(index).dispose()),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('admin-list-add-$key'),
                onPressed: max > 0 && rows.length >= max
                    ? null
                    : () => setState(() => rows.add(_ListRow(''))),
                icon: const Icon(Icons.add),
                label: const AppText('Új lehetőség'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionsField(Map<String, dynamic> field) {
    final key = '${field['key'] ?? ''}';
    if (_questions.isEmpty) _questions.add(_QuestionRow());
    return Card(
      key: Key('admin-field-$key'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${field['label'] ?? key}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _questions.length; index++)
              _questionCard(index),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('admin-question-add'),
                onPressed: () =>
                    setState(() => _questions.add(_QuestionRow())),
                icon: const Icon(Icons.add),
                label: const AppText('Új kérdés'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(int index) {
    final question = _questions[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trArgs(context, '{n}. kérdés', {'n': '${index + 1}'}),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Kérdés törlése'),
                  onPressed: _questions.length <= 1
                      ? null
                      : () => setState(() => _questions.removeAt(index).dispose()),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              key: Key('admin-question-$index-prompt'),
              controller: question.prompt,
              decoration: InputDecoration(labelText: tr(context, 'Kérdés szövege')),
            ),
            const SizedBox(height: 8),
            for (var option = 0; option < question.options.length; option++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Checkbox(
                      key: Key('admin-question-$index-correct-$option'),
                      value: question.correct == option,
                      onChanged: (checked) => setState(
                        () => question.correct = checked == true ? option : -1,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        key: Key('admin-question-$index-option-$option'),
                        controller: question.options[option].controller,
                        decoration: InputDecoration(
                          labelText: trArgs(context, '{n}. válasz', {
                            'n': '${option + 1}',
                          }),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Válasz törlése'),
                      onPressed: question.options.length <= 2
                          ? null
                          : () => setState(() {
                              question.options.removeAt(option).dispose();
                              if (question.correct >= question.options.length) {
                                question.correct = -1;
                              }
                            }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('admin-question-$index-add'),
                onPressed: question.options.length >= 6
                    ? null
                    : () => setState(
                        () => question.options.add(_ListRow('')),
                      ),
                icon: const Icon(Icons.add),
                label: const AppText('Új válasz'),
              ),
            ),
            AppText(
              'A helyes választ a sor elején pipáld ki (egy válasz).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
