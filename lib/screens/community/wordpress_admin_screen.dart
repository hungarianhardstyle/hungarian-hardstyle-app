import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/submission_image.dart';
import '../../providers/community_provider.dart';
import '../../widgets/submission_image_picker.dart';
import '../voting/voting_summary_screen.dart';

class WordPressAdminScreen extends ConsumerStatefulWidget {
  const WordPressAdminScreen({super.key});

  @override
  ConsumerState<WordPressAdminScreen> createState() =>
      _WordPressAdminScreenState();
}

class _WordPressAdminScreenState extends ConsumerState<WordPressAdminScreen> {
  final Set<int> _busyIds = <int>{};
  String _section = 'dashboard';
  String _search = '';
  late Future<dynamic> _request;

  static const _sections = <String, String>{
    'dashboard': 'Áttekintés',
    'huhs_release': 'Release-ek',
    'submissions': 'Beküldések',
    'huhs_event': 'Események',
    'huhs_artist': 'DJ-k',
    'huhs_organizer': 'Szervezők',
    'trash': 'Lomtár',
    'push': 'Push',
    'about': 'Névjegy',
    'startup': 'Indítási kép',
  };
  static const _customSections = <String>{
    'huhs_event',
    'huhs_artist',
    'huhs_organizer',
    'huhs_release',
  };

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _load() {
    final service = ref.read(communityServiceProvider);
    if (_section == 'submissions') return service.wordPressSubmissions();
    if (_section == 'dashboard' ||
        _section == 'push' ||
        _section == 'newsletter' ||
        _section == 'shortcodes' ||
        _section == 'about' ||
        _section == 'startup' ||
        _section == 'settings') {
      return service.wordPressAdminRequest(
        path: '/huhs/v1/admin?action=$_section',
      );
    }
    if (_section == 'trash') {
      return service.wordPressAdminRequest(path: '/huhs/v1/admin?action=trash');
    }
    return service.wordPressAdminRequest(
      path: '/wp/v2/$_section?per_page=100&context=edit',
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _request = _load();
    });
  }

  void _select(String section) {
    if (!mounted || _section == section) return;
    setState(() {
      _section = section;
      _request = _load();
    });
  }

  Future<void> _sendPush() async {
    var title = '';
    var body = '';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Egyedi push'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => title = value,
              decoration: const InputDecoration(labelText: 'Cím'),
            ),
            TextField(
              onChanged: (value) => body = value,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Üzenet'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (title.trim(), body.trim())),
            child: const Text('Küldés'),
          ),
        ],
      ),
    );
    if (result == null || result.$1.isEmpty || result.$2.isEmpty) return;
    try {
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/huhs/v1/admin',
            method: 'POST',
            body: {
              'action': 'send_push',
              'title': result.$1,
              'body': result.$2,
            },
          );
      _message('A push elküldve.');
    } catch (error) {
      _message('A push nem sikerült: ${_errorText(error)}');
    }
  }

  // Legacy callable retained for backend compatibility; not exposed in the UI.
  // ignore: unused_element
  Future<void> _sendPersonalizedPush() async {
    var kind = 'event';
    var id = '';
    var title = '';
    var body = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SzemĂ©lyre szabott push'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                items: const [
                  DropdownMenuItem(value: 'event', child: Text('EsemĂ©ny')),
                  DropdownMenuItem(
                    value: 'organizer',
                    child: Text('SzervezĹ‘'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => kind = value ?? kind),
                decoration: const InputDecoration(labelText: 'CĂ©ltĂ­pus'),
              ),
              TextField(
                onChanged: (value) => id = value,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ID'),
              ),
              TextField(
                onChanged: (value) => title = value,
                decoration: const InputDecoration(labelText: 'CĂ­m'),
              ),
              TextField(
                onChanged: (value) => body = value,
                decoration: const InputDecoration(labelText: 'Ăśzenet'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('MĂ©gse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('KĂĽldĂ©s'),
          ),
        ],
      ),
    );
    final parsedId = int.tryParse(id.trim());
    if (result != true ||
        parsedId == null ||
        title.trim().isEmpty ||
        body.trim().isEmpty)
      return;
    try {
      final sent = await ref
          .read(communityServiceProvider)
          .sendPersonalizedPush(
            kind: kind,
            id: parsedId,
            title: title.trim(),
            body: body.trim(),
          );
      _message('CĂ©lzottsĂ©gi push elkĂĽldve ($sent eszkĂ¶z).');
    } catch (error) {
      _message('A cĂ©lzottsĂ©gi push nem sikerĂĽlt: ${_errorText(error)}');
    }
  }

  Future<void> _manageSubmission(int id, String action) async {
    setState(() => _busyIds.add(id));
    try {
      await ref
          .read(communityServiceProvider)
          .manageWordPressSubmission(id: id, action: action);
      _reload();
    } catch (error) {
      _message('A művelet nem sikerült: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _editSubmission(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;
    final result = await _editDialog(
      item['title'] as String? ?? '',
      item['content'] as String? ?? '',
    );
    if (result == null) return;
    setState(() => _busyIds.add(id));
    try {
      await ref
          .read(communityServiceProvider)
          .updateWordPressSubmission(
            id: id,
            title: result.$1,
            content: result.$2,
          );
      _reload();
    } catch (error) {
      _message('A mentés nem sikerült: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _editResource(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null || id == 0 || _section == 'trash') {
      return;
    }
    if (_customSections.contains(_section)) {
      await _editCustomResource(id);
      return;
    }
    final isTaxonomy = _section == 'categories' || _section == 'tags';
    final isComment = _section == 'comments';
    final isMedia = _section == 'media';
    final title = isTaxonomy
        ? item['name']
        : isComment
        ? item['author_name']
        : item['title'] is Map
        ? item['title']['rendered']
        : item['title'];
    final content = isTaxonomy
        ? item['description']
        : item['content'] is Map
        ? item['content']['raw'] ?? item['content']['rendered']
        : item['content'];
    final result = await _editDialog(
      '$title' == 'null' ? '' : '$title',
      '$content' == 'null' ? '' : '$content',
    );
    if (result == null) return;
    setState(() => _busyIds.add(id));
    try {
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/wp/v2/$_section/$id',
            method: 'PUT',
            body: isTaxonomy
                ? {'name': result.$1, 'description': result.$2}
                : isComment
                ? {'content': result.$2}
                : isMedia
                ? {
                    'title': result.$1,
                    'caption': result.$2,
                    'description': result.$2,
                  }
                : {'title': result.$1, 'content': result.$2},
          );
      _reload();
    } catch (error) {
      _message('A mentés nem sikerült: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _editCustomResource(int id) async {
    final service = ref.read(communityServiceProvider);
    try {
      final raw = await service.wordPressAdminRequest(
        path: '/huhs/v1/admin?action=resource&type=$_section&id=$id',
      );
      if (raw is! Map || !mounted) return;
      final data = Map<String, dynamic>.from(raw);
      final fields = _items(data['fields']);
      final originalContent = '${data['content'] ?? ''}';
      final editableContent =
          html_parser.parseFragment(originalContent).text ?? '';
      final title = TextEditingController(text: '${data['title'] ?? ''}');
      final content = TextEditingController(text: editableContent);
      final controllers = <String, TextEditingController>{};
      final checks = <String, bool>{};
      final selectedIds = <String, Set<int>>{};
      for (final field in fields) {
        final key = '${field['key'] ?? ''}';
        if (key.isEmpty) continue;
        if (field['type'] == 'bool') {
          final value = field['value'];
          checks[key] = value == true || value == 1 || value == '1';
        } else if (field['type'] == 'ids' && field['options'] is List) {
          selectedIds[key] = _decodeIds('${field['value'] ?? ''}').toSet();
        } else {
          controllers[key] = TextEditingController(
            text: '${field['value'] ?? ''}',
          );
        }
      }
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Szerkesztés: ${_sections[_section]}'),
            content: SizedBox(
              width: 520,
              height: MediaQuery.sizeOf(context).height * .65,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: title,
                        decoration: const InputDecoration(labelText: 'Cím'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: content,
                        minLines: 4,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'Tartalom',
                        ),
                      ),
                    ),
                    for (final field in fields)
                      _adminField(
                        field,
                        controllers,
                        checks,
                        selectedIds,
                        setDialogState,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Mentés'),
              ),
            ],
          ),
        ),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      final saveBody = result == true
          ? <String, dynamic>{
              'action': 'save_resource',
              'id': id,
              'type': _section,
              'title': title.text.trim(),
              'content': content.text,
              'contentChanged': content.text != editableContent,
              'meta': {
                for (final entry in controllers.entries)
                  entry.key: entry.value.text.trim(),
                for (final entry in selectedIds.entries)
                  entry.key: entry.value.join(','),
                ...checks,
              },
            }
          : null;
      // Let the dialog route finish before disposing focused text controllers.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      title.dispose();
      content.dispose();
      for (final controller in controllers.values) {
        controller.dispose();
      }
      if (!mounted || saveBody == null) return;
      if (result == true) {
        await service.wordPressAdminRequest(
          path: '/huhs/v1/admin',
          method: 'POST',
          body: saveBody,
        );
        _message('Az elem mentve.');
        _reload();
      }
    } catch (error) {
      _message('A szerkesztés nem sikerült: ${_errorText(error)}');
    }
  }

  static const _creatableSections = <String>{
    'huhs_event',
    'huhs_artist',
    'huhs_organizer',
  };

  Widget _adminField(
    Map<String, dynamic> field,
    Map<String, TextEditingController> controllers,
    Map<String, bool> checks,
    Map<String, Set<int>> selectedIds,
    void Function(void Function()) setDialogState,
  ) {
    final key = '${field['key'] ?? ''}';
    final label = '${field['label'] ?? key}';
    if (field['type'] == 'bool') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: checks[key] ?? false,
          onChanged: (value) => setDialogState(() => checks[key] = value),
        ),
      );
    }
    final options = _items(field['options']);
    if (field['type'] == 'ids' && options.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: options.map((option) {
              final optionId = (option['id'] as num?)?.toInt() ?? 0;
              final selected = selectedIds[key]?.contains(optionId) ?? false;
              return FilterChip(
                label: Text('${option['label'] ?? optionId}'),
                selected: selected,
                onSelected: optionId == 0
                    ? null
                    : (value) => setDialogState(() {
                        final values = selectedIds[key] ?? <int>{};
                        value ? values.add(optionId) : values.remove(optionId);
                        selectedIds[key] = values;
                      }),
              );
            }).toList(),
          ),
        ),
      );
    }
    if (key == 'organizer_id' && options.isNotEmpty) {
      final current = int.tryParse(controllers[key]?.text ?? '');
      final validCurrent = options.any((item) => item['id'] == current)
          ? current
          : null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<int>(
          initialValue: validCurrent,
          decoration: InputDecoration(labelText: label),
          items: options.map((option) {
            final optionId = (option['id'] as num?)?.toInt() ?? 0;
            return DropdownMenuItem<int>(
              value: optionId,
              child: Text('${option['label'] ?? optionId}'),
            );
          }).toList(),
          onChanged: (value) => controllers[key]?.text = '${value ?? 0}',
        ),
      );
    }
    final controller = controllers[key];
    if (controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: field['type'] == 'int'
            ? TextInputType.number
            : field['type'] == 'email'
            ? TextInputType.emailAddress
            : field['type'] == 'url'
            ? TextInputType.url
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  List<int> _decodeIds(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .map((item) => int.tryParse('$item') ?? 0)
            .where((id) => id > 0)
            .toList();
      }
    } catch (_) {}
    return value
        .split(RegExp(r'[\s,]+'))
        .map((item) => int.tryParse(item) ?? 0)
        .where((id) => id > 0)
        .toList();
  }

  Future<void> _createResource() async {
    if (!_creatableSections.contains(_section)) return;
    final result = await _editDialog('', '');
    if (result == null || result.$1.trim().isEmpty) return;
    try {
      final isTaxonomy = _section == 'categories' || _section == 'tags';
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/wp/v2/$_section',
            method: 'POST',
            body: isTaxonomy
                ? {'name': result.$1.trim()}
                : {
                    'title': result.$1.trim(),
                    'content': result.$2,
                    'status': 'draft',
                  },
          );
      _message('Az elem létrehozva.');
      _reload();
    } catch (error) {
      _message('A létrehozás nem sikerült: ${_errorText(error)}');
    }
  }

  Future<void> _editUser(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;
    final name = TextEditingController(text: item['name'] as String? ?? '');
    final email = TextEditingController(text: item['email'] as String? ?? '');
    final roles = item['roles'] as List?;
    var role = roles?.isNotEmpty == true
        ? roles!.first.toString()
        : 'subscriber';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Felhasználó szerkesztése'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Név'),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
              ),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(
                  labelText: 'WordPress-szerepkör',
                ),
                items:
                    const [
                          'administrator',
                          'editor',
                          'author',
                          'contributor',
                          'subscriber',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => role = value ?? role,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    final body = {
      'name': name.text.trim(),
      'email': email.text.trim(),
      'roles': [role],
    };
    name.dispose();
    email.dispose();
    if (result != true) return;
    try {
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/wp/v2/users/$id',
            method: 'PUT',
            body: body,
          );
      _reload();
    } catch (error) {
      _message('A felhasználó mentése nem sikerült: ${_errorText(error)}');
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    if (id == 0 ||
        !await _confirm(
          'Felhasználó törlése',
          'Biztosan törlöd ezt a WordPress-felhasználót? A művelet nem vonható vissza.',
        )) {
      return;
    }
    try {
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/wp/v2/users/$id?force=true&reassign=1',
            method: 'DELETE',
          );
      _reload();
    } catch (error) {
      _message('A felhasználó törlése nem sikerült: ${_errorText(error)}');
    }
  }

  Future<void> _trashResource(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null || id == 0 || _section == 'trash') {
      return;
    }
    final ok = await _confirm(
      'Áthelyezés a lomtárba',
      'Biztosan áthelyezed ezt az elemet a lomtárba?',
    );
    if (!ok) return;
    try {
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/wp/v2/$_section/$id',
            method: 'DELETE',
          );
      _reload();
    } catch (error) {
      _message('A törlés nem sikerült: ${_errorText(error)}');
    }
  }

  Future<void> _emptyTrash() async {
    if (!await _confirm(
      'Lomtár ürítése',
      'A művelet véglegesen törli a lomtár tartalmát. Folytatod?',
    )) {
      return;
    }
    try {
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/huhs/v1/admin',
            method: 'POST',
            body: {'action': 'empty_trash'},
          );
      _message('A lomtár kiürítve.');
      _reload();
    } catch (error) {
      _message('A lomtár ürítése nem sikerült: ${_errorText(error)}');
    }
  }

  Future<void> _restoreTrash(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null || id == 0) return;
    try {
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/huhs/v1/admin',
            method: 'POST',
            body: {'action': 'restore', 'id': id},
          );
      _reload();
    } catch (error) {
      _message('A visszaállítás nem sikerült: ${_errorText(error)}');
    }
  }

  Future<(String, String)?> _editDialog(
    String initialTitle,
    String initialContent,
  ) async {
    final title = TextEditingController(text: initialTitle);
    final content = TextEditingController(text: initialContent);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Szerkesztés: ${_sections[_section]}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Cím'),
              ),
              TextField(
                controller: content,
                minLines: 4,
                maxLines: 12,
                decoration: const InputDecoration(labelText: 'Tartalom'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (title.text.trim(), content.text)),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    title.dispose();
    content.dispose();
    return result;
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Igen'),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.split('\n#0').first.trim())));
    }
  }

  String _errorText(Object? error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'A művelet nem sikerült.';
    }
    return '${error ?? ''}'.split('\n#0').first.trim();
  }

  List<Map<String, dynamic>> _items(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map && data['items'] is List) return _items(data['items']);
    return const [];
  }

  String _plainText(Object? value) =>
      html_parser.parseFragment('${value ?? ''}').text?.trim() ?? '';

  Future<void> _editStartup(Map<String, dynamic> data) async {
    final service = ref.read(communityServiceProvider);
    final url = TextEditingController(text: data['imageUrl']?.toString() ?? '');
    var enabled = data['enabled'] == true;
    SubmissionImage? image;
    final result = await showDialog<(String, bool, SubmissionImage?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Indítási kép'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SubmissionImagePicker(
                  image: image,
                  title: 'Kép feltöltése',
                  helperText:
                      'A kép Cloudinary-ra kerül, és az app indulásakor bezárható.',
                  onChanged: (value) => setDialogState(() => image = value),
                ),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'Kép URL-je'),
                  keyboardType: TextInputType.url,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Megjelenítés engedélyezése'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(dialogContext, ('', false, null)),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Kép törlése'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, (
                url.text.trim(),
                enabled,
                image,
              )),
              child: const Text('Mentés'),
            ),
          ],
        ),
      ),
    );
    url.dispose();
    if (result == null) return;
    try {
      var imageUrl = result.$1;
      if (result.$3 != null) {
        imageUrl = await service.uploadImage(
          result.$3!.bytes,
          filename: result.$3!.name,
        );
      }
      if (result.$2 && imageUrl.isEmpty) {
        _message('Bekapcsolva csak kép URL-lel menthető.');
        return;
      }
      await service.wordPressAdminRequest(
        path: '/huhs/v1/admin',
        method: 'POST',
        body: {
          'action': 'save_startup',
          'imageUrl': imageUrl,
          'enabled': result.$2,
        },
      );
      _message(
        imageUrl.isEmpty ? 'Indítási kép törölve.' : 'Indítási kép mentve.',
      );
      _reload();
    } catch (error) {
      final message = _errorText(error);
      _message(
        'Az indítási kép mentése nem sikerült: '
        '${message.contains('Ismeretlen admin művelet') ? 'a HUHS Mobile API 2.4.32 feltöltése szükséges.' : message}',
      );
    }
  }

  Widget _special(dynamic data) {
    if (data is! Map) return const Center(child: Text('Nincs adat.'));
    final entries = data.entries
        .where((entry) => entry.key != 'items' && entry.key != 'sections')
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_section == 'dashboard')
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const VotingSummaryScreen(),
              ),
            ),
            icon: const Icon(Icons.bar_chart_outlined),
            label: const Text('Szavazási összesítő'),
          ),
        if (_section == 'push')
          FilledButton.icon(
            onPressed: _sendPush,
            icon: const Icon(Icons.send),
            label: const Text('Egyedi push létrehozása'),
          ),
        if (_section == 'startup')
          FilledButton.icon(
            onPressed: () => _editStartup(Map<String, dynamic>.from(data)),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Indítási kép kezelése'),
          ),
        if (_section == 'trash')
          FilledButton.icon(
            onPressed: _emptyTrash,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Lomtár ürítése'),
          ),
        ...entries.map(
          (entry) => Card(
            child: ListTile(
              title: Text('${entry.key}'),
              subtitle: Text('${entry.value}'),
            ),
          ),
        ),
        if (_section == 'shortcodes' && data['items'] is List)
          ..._items(data['items']).map(
            (item) => Card(
              child: ListTile(
                title: Text('${item['name']}'),
                subtitle: Text('${item['description']}'),
              ),
            ),
          ),
        if (_section == 'trash' && data['items'] is List)
          ..._items(data['items']).map(_item),
      ],
    );
  }

  Widget _submissionItem(Map<String, dynamic> item) {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final busy = _busyIds.contains(id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(item['title'] as String? ?? ''),
              subtitle: Text('Beküldés #$id'),
            ),
            Text(
              '${item['content'] ?? item['description'] ?? ''}',
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            OverflowBar(
              children: [
                OutlinedButton.icon(
                  onPressed: busy || id == 0
                      ? null
                      : () => _editSubmission(item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Szerkesztés'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || id == 0
                      ? null
                      : () => _manageSubmission(id, 'trash'),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Lomtár'),
                ),
                FilledButton.icon(
                  onPressed: busy || id == 0
                      ? null
                      : () => _manageSubmission(id, 'approve'),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Jóváhagyás és piszkozat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(Map<String, dynamic> item) {
    if (_section == 'submissions') return _submissionItem(item);
    if (_section == 'trash') {
      return Card(
        child: ListTile(
          title: Text('${item['title'] ?? ''}'),
          subtitle: Text('${item['type'] ?? ''} #${item['id'] ?? ''}'),
          trailing: IconButton(
            onPressed: () => _restoreTrash(item),
            icon: const Icon(Icons.restore),
          ),
        ),
      );
    }
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final title = _section == 'categories' || _section == 'tags'
        ? item['name']
        : _section == 'comments'
        ? item['author_name']
        : _section == 'users'
        ? item['name']
        : item['title'] is Map
        ? item['title']['rendered']
        : item['title'];
    final content = item['content'] is Map
        ? item['content']['rendered']
        : item['content'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(title: Text(_plainText(title)), subtitle: Text('#$id')),
            if (content != null)
              Text(
                _plainText(content),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            OverflowBar(
              children: _section == 'users'
                  ? [
                      OutlinedButton.icon(
                        onPressed: id == 0 ? null : () => _editUser(item),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Szerkesztés'),
                      ),
                      OutlinedButton.icon(
                        onPressed: id == 0 ? null : () => _deleteUser(item),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Törlés'),
                      ),
                    ]
                  : [
                      OutlinedButton.icon(
                        onPressed: id == 0 ? null : () => _editResource(item),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Szerkesztés'),
                      ),
                      OutlinedButton.icon(
                        onPressed: id == 0 ? null : () => _trashResource(item),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Lomtár'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final special = {
      'dashboard',
      'settings',
      'push',
      'newsletter',
      'shortcodes',
      'about',
      'startup',
      'trash',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUHS Vezérlőközpont'),
        actions: [
          if (_creatableSections.contains(_section))
            IconButton(
              tooltip: 'Új elem',
              onPressed: _createResource,
              icon: const Icon(Icons.add),
            ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _sections.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 8,
                      ),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _section == entry.key,
                        onSelected: (_) => _select(entry.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_section == 'users')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Felhasználó keresése',
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<dynamic>(
              future: _request,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Az adatok nem tölthetők be.\n${_errorText(snapshot.error)}',
                    ),
                  );
                }
                if (special.contains(_section)) return _special(snapshot.data);
                var values = _items(snapshot.data);
                if (_section == 'users' && _search.trim().isNotEmpty) {
                  final query = _search.trim().toLowerCase();
                  values = values.where((item) {
                    final searchable = [
                      item['name'],
                      item['slug'],
                      item['username'],
                      item['email'],
                      item['id'],
                    ].map((value) => '$value').join(' ').toLowerCase();
                    return searchable.contains(query);
                  }).toList();
                }
                if (values.isEmpty) {
                  return Center(
                    child: Text(
                      _section == 'trash'
                          ? 'A lomtár üres.'
                          : 'Nincs megjeleníthető elem.',
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: values.length,
                    itemBuilder: (context, index) => _item(values[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
