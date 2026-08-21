import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/errors/user_facing_error.dart';
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
        error: (error, stack) => Center(
          child: Text(userFacingError(error), textAlign: TextAlign.center),
        ),
        data: (data) => FutureBuilder<Map<String, dynamic>>(
          future: FirebaseFunctions.instance
              .httpsCallable('getVotingSummary')
              .call<Map<String, dynamic>>({'seasonId': data.seasonId})
              .then((result) => Map<String, dynamic>.from(result.data)),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final counts = <String, int>{};
            final rawCounts = snapshot.data!['counts'];
            if (rawCounts is Map) {
              rawCounts.forEach(
                (key, value) => counts['$key'] = (value as num).toInt(),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Összes szavazat: ${snapshot.data!['totalVotes'] ?? 0}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final category in data.categories)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final candidate in category.candidates)
                            ListTile(
                              dense: true,
                              title: Text(candidate.name),
                              trailing: Text(
                                '${counts['${category.key}:${candidate.id}'] ?? 0}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
