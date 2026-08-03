import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/faq.dart';
import '../../providers/news_provider.dart';

final faqProvider = FutureProvider<List<FaqItem>>((ref) {
  return ref.watch(wordpressServiceProvider).getFaq();
});

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  String _query = '';
  String _category = 'Összes';

  @override
  Widget build(BuildContext context) {
    final asyncFaq = ref.watch(faqProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GYIK / FAQ')),
      body: asyncFaq.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'A GYIK nem tölthető be.',
          onRetry: () => ref.invalidate(faqProvider),
        ),
        data: (items) {
          final categories = <String>{'Összes', ...items.map((e) => e.category)}
            ..removeWhere((value) => value.trim().isEmpty);
          final visible = items.where((item) {
            final matchesCategory =
                _category == 'Összes' || item.category == _category;
            final query = _query.trim().toLowerCase();
            return matchesCategory &&
                (query.isEmpty ||
                    item.question.toLowerCase().contains(query) ||
                    item.answer.toLowerCase().contains(query));
          }).toList()..sort((a, b) => a.order.compareTo(b.order));
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Keresés a GYIK-ben...',
                ),
              ),
              if (categories.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final category = categories.elementAt(index);
                      return ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('Nincs találat.')),
                ),
              ...visible.map(
                (item) => Card(
                  child: ExpansionTile(
                    title: Text(item.question),
                    subtitle: item.category.isEmpty
                        ? null
                        : Text(item.category),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [Text(item.answer)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Újrapróbálás'),
        ),
      ],
    ),
  );
}
