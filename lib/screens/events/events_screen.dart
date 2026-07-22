import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/events_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/event_card.dart';
import 'event_submission_screen.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  void _openSubmission(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const EventSubmissionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final user = ref.watch(communityAuthProvider).valueOrNull;
    final canSubmit = user != null && !user.isAnonymous;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(eventsProvider);
              await ref.read(eventsProvider.future);
            },
            child: events.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                children: [
                  _EventsHeader(
                    onSubmit: () => _openSubmission(context),
                    showSubmit: canSubmit,
                  ),
                  const SizedBox(height: 100),
                  const Center(child: CircularProgressIndicator()),
                ],
              ),
              error: (error, stack) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                children: [
                  _EventsHeader(
                    onSubmit: () => _openSubmission(context),
                    showSubmit: canSubmit,
                  ),
                  const SizedBox(height: 80),
                  const Text(
                    'Nem sikerült betölteni az eseményeket.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => ref.invalidate(eventsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Újrapróbálás'),
                    ),
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    children: [
                      _EventsHeader(
                        onSubmit: () => _openSubmission(context),
                        showSubmit: canSubmit,
                      ),
                      const SizedBox(height: 80),
                      const Center(
                        child: Text(
                          'Nincs közelgő esemény.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _EventsHeader(
                          onSubmit: () => _openSubmission(context),
                          showSubmit: canSubmit,
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: EventCard(event: items[index - 1]),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EventsHeader extends StatelessWidget {
  final VoidCallback onSubmit;
  final bool showSubmit;

  const _EventsHeader({required this.onSubmit, required this.showSubmit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Események',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (showSubmit)
          OutlinedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Esemény beküldése'),
        ),
      ],
    );
  }
}
