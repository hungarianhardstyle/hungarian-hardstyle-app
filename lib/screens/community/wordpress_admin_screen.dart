import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import '../../models/submission_image.dart';
import '../../core/errors/user_facing_error.dart';
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
  bool _sendingPush = false;
  String _section = 'dashboard';
  String _search = '';
  late Future<dynamic> _request;

  static const _sections = <String, String>{
    'dashboard': 'Áttekintés',
    'games': 'Játékok',
    'voting_summary': 'Szavazási állás',
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
  static const _adminFieldLabels = <String, String>{
    'apiVersion': 'API-verzió',
    'artists': 'DJ-k száma',
    'organizers': 'Szervezők száma',
    'events': 'Események száma',
    'submissions': 'Függőben lévő beküldések',
    'baseUrl': 'API-cím',
    'imageUpload': 'Képfeltöltés',
    'moderatedSubmissions': 'Beküldések moderálása',
    'project': 'Projekt',
    'developer': 'Fejlesztő',
    'website': 'Weboldal',
    'configured': 'Beállítás állapota',
    'registeredDevices': 'Regisztrált eszközök',
    'audienceId': 'Célközönség azonosítója',
    'dataCenter': 'Adatközpont',
  };

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _load() async {
    await FirebaseAuth.instance.authStateChanges().first;
    final service = ref.read(communityServiceProvider);
    if (_section == 'submissions') return service.wordPressSubmissions();
    if (_section == 'dashboard' ||
        _section == 'games' ||
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
    if (section == 'voting_summary') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VotingSummaryScreen()),
      );
      return;
    }
    setState(() {
      _section = section;
      _request = _load();
    });
  }

  String _pushTargetLabel(String value, List<Map<String, dynamic>> targets) {
    if (value == 'none') return 'Nincs cél';
    if (value == 'url') return 'Egyedi link';
    for (final item in targets) {
      final id = (item['id'] as num?)?.toInt();
      final type = item['type']?.toString() ?? '';
      if (id == null || '$type:$id' != value) continue;
      final kind = switch (type) {
        'news' => 'Cikk',
        'event' => 'Esemény',
        'release' => 'Release',
        _ => 'Tartalom',
      };
      return '$kind: ${item['title'] ?? id}';
    }
    return 'Nincs cél';
  }

  Future<String?> _selectPushTarget(List<Map<String, dynamic>> targets) async {
    final searchController = TextEditingController();
    var query = '';
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = targets
                .where((item) {
                  if (normalizedQuery.isEmpty) return true;
                  return '${item['title'] ?? ''}'.toLowerCase().contains(
                    normalizedQuery,
                  );
                })
                .toList(growable: false);
            return AlertDialog(
              title: const Text('Megnyitandó tartalom'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(dialogContext).height * .62,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: (value) => setDialogState(() => query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Keresés a címek között',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.notifications_none),
                            title: const Text('Nincs cél'),
                            onTap: () => Navigator.pop(dialogContext, 'none'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.link),
                            title: const Text('Egyedi link'),
                            subtitle: const Text('HTTPS-link megadása'),
                            onTap: () => Navigator.pop(dialogContext, 'url'),
                          ),
                          const Divider(),
                          ...filtered.map((item) {
                            final id = (item['id'] as num).toInt();
                            final type = item['type'].toString();
                            final kind = switch (type) {
                              'news' => 'Cikk',
                              'event' => 'Esemény',
                              'release' => 'Release',
                              _ => 'Tartalom',
                            };
                            return ListTile(
                              leading: Icon(
                                type == 'news'
                                    ? Icons.article_outlined
                                    : type == 'event'
                                    ? Icons.event_outlined
                                    : Icons.album_outlined,
                              ),
                              title: Text(
                                '$kind: ${item['title'] ?? id}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () =>
                                  Navigator.pop(dialogContext, '$type:$id'),
                            );
                          }),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Nincs találat.'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Mégse'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _sendPush(Map<String, dynamic> pushData) async {
    if (_sendingPush) return;
    var title = '';
    var body = '';
    var selectedTarget = 'none';
    var customUrl = '';
    final targets = (pushData['targets'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) =>
              (item['id'] as num?) != null &&
              (item['type']?.toString().trim().isNotEmpty ?? false),
        )
        .toList(growable: false);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Egyedi push'),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    final value = await _selectPushTarget(targets);
                    if (value != null) {
                      setDialogState(() => selectedTarget = value);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Megnyitandó tartalom',
                      suffixIcon: Icon(Icons.open_in_new),
                    ),
                    child: Text(
                      _pushTargetLabel(selectedTarget, targets),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (selectedTarget == 'url') ...[
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => customUrl = value,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'HTTPS-link',
                      hintText: 'https://...',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () {
                final parts = selectedTarget.split(':');
                Navigator.pop(dialogContext, {
                  'title': title.trim(),
                  'body': body.trim(),
                  'targetType': parts.first,
                  'targetId': parts.length == 2
                      ? int.tryParse(parts.last) ?? 0
                      : 0,
                  'url': selectedTarget == 'url' ? customUrl.trim() : '',
                });
              },
              child: const Text('Küldés'),
            ),
          ],
        ),
      ),
    );
    if (result == null ||
        (result['title'] as String).isEmpty ||
        (result['body'] as String).isEmpty) {
      return;
    }
    if (result['targetType'] == 'url') {
      final uri = Uri.tryParse(result['url'] as String);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        _message('Érvényes HTTPS-linket adj meg.');
        return;
      }
    }
    if (mounted) setState(() => _sendingPush = true);
    try {
      await ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(
            path: '/huhs/v1/admin',
            method: 'POST',
            body: {
              'action': 'send_push',
              'title': result['title'],
              'body': result['body'],
              'targetType': result['targetType'],
              'targetId': result['targetId'],
              'url': result['url'],
            },
          );
      _message('A push elküldve.');
    } catch (error) {
      _message('A push nem sikerült: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _sendingPush = false);
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
      final currentLabel = options
          .where((item) => item['id'] == validCurrent)
          .map((item) => '${item['label'] ?? item['id'] ?? ''}')
          .cast<String>()
          .toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final selected = await showModalBottomSheet<int>(
              context: context,
              showDragHandle: true,
              builder: (sheetContext) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(title: Text(label)),
                    for (final option in options)
                      ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: Text('${option['label'] ?? option['id'] ?? ''}'),
                        selected: option['id'] == validCurrent,
                        onTap: () => Navigator.pop(
                          sheetContext,
                          (option['id'] as num?)?.toInt(),
                        ),
                      ),
                  ],
                ),
              ),
            );
            if (selected != null) {
              setDialogState(() => controllers[key]?.text = '$selected');
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Text(
              currentLabel.isEmpty ? 'Nincs kiválasztva' : currentLabel.first,
            ),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.split('\n#0').first.trim()),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  String _errorText(Object? error) {
    return userFacingError(error);
    /* Legacy technical error formatting is intentionally unreachable. */
    /*
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'A művelet nem sikerült.';
    }
    return '${error ?? ''}'.split('\n#0').first.trim();
  }

    */
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

  String _adminFieldLabel(Object key) =>
      _adminFieldLabels[key.toString()] ?? key.toString();

  String _adminFieldValue(Object? value) {
    if (value == true) return 'Igen';
    if (value == false) return 'Nem';
    return '$value';
  }

  Future<void> _editStartup(Map<String, dynamic> data) async {
    final service = ref.read(communityServiceProvider);
    final url = TextEditingController(text: data['imageUrl']?.toString() ?? '');
    final buttonLabel = TextEditingController(
      text: data['buttonLabel']?.toString() ?? '',
    );
    final buttonUrl = TextEditingController(
      text: data['buttonUrl']?.toString() ?? '',
    );
    var enabled = data['enabled'] == true;
    SubmissionImage? image;
    final result =
        await showDialog<(String, bool, SubmissionImage?, String, String?)>(
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
                      helperText: 'A kép Cloudinary-ra kerül, és az app indulásakor bezárható.',
                      onChanged: (value) => setDialogState(() => image = value),
                    ),
                    TextField(
                      controller: url,
                      decoration: const InputDecoration(
                        labelText: 'Kép URL-je',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    TextField(
                      controller: buttonLabel,
                      decoration: const InputDecoration(
                        labelText: 'Gomb felirata (például: Jegyek)',
                      ),
                      maxLength: 40,
                    ),
                    TextField(
                      controller: buttonUrl,
                      decoration: const InputDecoration(
                        labelText: 'Gomb linkje (HTTPS)',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Megjelenítés engedélyezése'),
                      value: enabled,
                      onChanged: (value) =>
                          setDialogState(() => enabled = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(dialogContext, ('', false, null, '', null)),
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
                    buttonLabel.text.trim(),
                    buttonUrl.text.trim().isEmpty
                        ? null
                        : buttonUrl.text.trim(),
                  )),
                  child: const Text('Mentés'),
                ),
              ],
            ),
          ),
        );
    url.dispose();
    buttonLabel.dispose();
    buttonUrl.dispose();
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
      final buttonLabelValue = result.$4.trim();
      final buttonUrlValue = result.$5?.trim() ?? '';
      final parsedButtonUrl = Uri.tryParse(buttonUrlValue);
      if (buttonUrlValue.isNotEmpty &&
          (buttonLabelValue.isEmpty ||
              buttonLabelValue.length > 40 ||
              parsedButtonUrl == null ||
              parsedButtonUrl.scheme != 'https' ||
              parsedButtonUrl.host.isEmpty)) {
        _message(
          'A gombhoz érvényes HTTPS-link és 1–40 karakteres felirat kell.',
        );
        return;
      }
      await service.wordPressAdminRequest(
        path: '/huhs/v1/admin',
        method: 'POST',
        body: {
          'action': 'save_startup',
          'imageUrl': imageUrl,
          'enabled': result.$2,
          'buttonLabel': buttonUrlValue.isEmpty ? '' : buttonLabelValue,
          'buttonUrl': buttonUrlValue,
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
    if (_section == 'games') return _gameAdminList(data);
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
            onPressed: _sendingPush
                ? null
                : () => _sendPush(Map<String, dynamic>.from(data)),
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
        if (_section != 'push')
          ...entries.map(
            (entry) => Card(
              child: ListTile(
                title: Text(_adminFieldLabel(entry.key)),
                subtitle: Text(_adminFieldValue(entry.value)),
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

  Widget _gameAdminList(Map<dynamic, dynamic> data) {
    final games = _items(data['items']);
    if (games.isEmpty) {
      return const Center(child: Text('Nincs még játék az adatbázisban.'));
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: games.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final game = games[index];
          final status = '${game['status_label'] ?? game['status'] ?? ''}';
          final artwork = '${game['artwork'] ?? ''}';
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (artwork.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: artwork,
                    height: 120,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ListTile(
                  title: Text(
                    '${game['title'] ?? 'Játék'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${game['type_label'] ?? 'Játék'}  •  $status\n'
                    'Beküldések: ${game['submissions'] ?? 0}  •  '
                    'Helyes válaszok: ${game['correct_answers'] ?? 0}/'
                    '${game['total_answers'] ?? 0}',
                  ),
                  isThreeLine: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    'Időszak: ${_adminDate(game['start_at'])} – ${_adminDate(game['end_at'])}\n'
                    'Jutalom: ${game['reward_points'] ?? 0} pont  •  '
                    'Kérdések: ${game['question_count'] ?? 0}  •  '
                    'Idővonal-elemek: ${game['timeline_count'] ?? 0}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _adminDate(Object? value) {
    final raw = '$value'.trim();
    if (raw.isEmpty || raw == 'null') return '—';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')} ${parsed.hour}:$minute';
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
      'games',
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
