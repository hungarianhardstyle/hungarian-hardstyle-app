import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/community_provider.dart';

class WordPressAdminScreen extends ConsumerStatefulWidget {
  const WordPressAdminScreen({super.key});

  @override
  ConsumerState<WordPressAdminScreen> createState() => _WordPressAdminScreenState();
}

class _WordPressAdminScreenState extends ConsumerState<WordPressAdminScreen> {
  late Future<List<Map<String, dynamic>>> _request;
  final Set<int> _busyIds = <int>{};

  @override
  void initState() {
    super.initState();
    _request = ref.read(communityServiceProvider).wordPressSubmissions();
  }

  void _reload() {
    setState(() {
      _request = ref.read(communityServiceProvider).wordPressSubmissions();
    });
  }

  Future<void> _manage(int id, String action) async {
    setState(() => _busyIds.add(id));
    try {
      await ref.read(communityServiceProvider).manageWordPressSubmission(
            id: id,
            action: action,
          );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A művelet nem sikerült: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;
    final titleController = TextEditingController(text: item['title'] as String? ?? '');
    final contentController = TextEditingController(
      text: item['content'] as String? ?? item['description'] as String? ?? '',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Beküldés szerkesztése'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Cím')),
              TextField(
                controller: contentController,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Tartalom'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Mégse')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Mentés')),
        ],
      ),
    );
    if (save != true || !mounted) {
      titleController.dispose();
      contentController.dispose();
      return;
    }
    final title = titleController.text.trim();
    final content = contentController.text;
    titleController.dispose();
    contentController.dispose();
    if (title.isEmpty) return;
    setState(() => _busyIds.add(id));
    try {
      await ref.read(communityServiceProvider).updateWordPressSubmission(
            id: id,
            title: title,
            content: content,
          );
      _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('A mentés nem sikerült: $error')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUHS Vezérlőközpont'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _request,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('A beküldések nem tölthetők be.\n${snapshot.error}'));
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return const Center(child: Text('Nincs függőben lévő beküldés.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final id = (item['id'] as num?)?.toInt() ?? 0;
                final busy = _busyIds.contains(id);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ExpansionTile(
                          title: Text(item['title'] as String? ?? ''),
                          subtitle: Text('Beküldés #$id'),
                          children: [
                            if ((item['type'] ?? item['post_type']) != null)
                              ListTile(
                                dense: true,
                                title: const Text('Típus'),
                                subtitle: Text(
                                  '${item['type'] ?? item['post_type']}',
                                ),
                              ),
                            if ((item['content'] ?? item['description']) != null)
                              ListTile(
                                dense: true,
                                title: const Text('Tartalom'),
                                subtitle: Text(
                                  '${item['content'] ?? item['description']}',
                                  maxLines: 8,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        OverflowBar(
                          children: [
                            OutlinedButton.icon(
                              onPressed: busy || id == 0 ? null : () => _edit(item),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Szerkesztés'),
                            ),
                            OutlinedButton.icon(
                              onPressed: busy || id == 0 ? null : () => _manage(id, 'trash'),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Kuka'),
                            ),
                            FilledButton.icon(
                              onPressed: busy || id == 0 ? null : () => _manage(id, 'approve'),
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
              },
            ),
          );
        },
      ),
    );
  }
}
