import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/voting_provider.dart';

class VotingSummaryScreen extends ConsumerWidget {
  const VotingSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final season = ref.watch(votingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Szavazási összesítő')),
      body: season.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (data) => FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('voting_votes').where('seasonId', isEqualTo: data.seasonId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final counts = <String, int>{};
            for (final vote in snapshot.data!.docs) {
              final data = vote.data();
              final candidates = (data['candidateIds'] as List<dynamic>?) ?? [data['candidateId']];
              for (final id in candidates) {
                final key = '${data['category']}:$id';
                counts[key] = (counts[key] ?? 0) + 1;
              }
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Összes szavazat: ${snapshot.data!.docs.length}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final category in data.categories)
                  Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(category.label, style: Theme.of(context).textTheme.titleMedium),
                    for (final candidate in category.candidates)
                      ListTile(dense: true, title: Text(candidate.name), trailing: Text('${counts['${category.key}:${candidate.id}'] ?? 0}')),
                  ]))),
              ],
            );
          },
        ),
      ),
    );
  }
}
