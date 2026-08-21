import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/events_provider.dart';
import '../../providers/community_provider.dart';
import '../../models/event.dart';
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
    final pastEvents = ref.watch(pastEventsProvider);
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
              ref.invalidate(pastEventsProvider);
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
                final pastSection = _PastEventsSection(events: pastEvents);
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
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ),
                      pastSection,
                    ],
                  );
                }

                final featured = items
                    .where((event) => event.featured)
                    .toList();
                final regular = items
                    .where((event) => !event.featured)
                    .toList();
                final landscape =
                    MediaQuery.orientationOf(context) == Orientation.landscape;
                final sections = <Widget>[
                  _EventsHeader(
                    onSubmit: () => _openSubmission(context),
                    showSubmit: canSubmit,
                  ),
                  if (featured.isNotEmpty) ...[
                    const _EventsSectionTitle('Kiemelt események'),
                    ...featured.map((event) => EventCard(event: event)),
                  ],
                  if (regular.isNotEmpty) ...[
                    const _EventsSectionTitle('Események'),
                    ...regular.map((event) => EventCard(event: event)),
                  ],
                  pastSection,
                ];
                if (!landscape) {
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    itemCount: sections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 18),
                    itemBuilder: (_, index) => sections[index],
                  );
                }
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  children: [
                    sections.first,
                    if (featured.isNotEmpty) ...[
                      const _EventsSectionTitle('Kiemelt események'),
                      _EventGrid(events: featured),
                    ],
                    if (regular.isNotEmpty) ...[
                      const _EventsSectionTitle('Események'),
                      _EventGrid(events: regular),
                    ],
                    pastSection,
                  ],
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

class _EventsSectionTitle extends StatelessWidget {
  final String title;

  const _EventsSectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      title,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    ),
  );
}

class _PastEventsSection extends StatelessWidget {
  final AsyncValue<List<HuhsEvent>> events;

  const _PastEventsSection({required this.events});

  @override
  Widget build(BuildContext context) {
    final items = events.valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Korábbi események'),
      subtitle: Text('${items.length} lejárt esemény'),
      children: [
        for (final event in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EventCard(event: event),
          ),
      ],
    );
  }
}

class _EventGrid extends StatelessWidget {
  final List<HuhsEvent> events;

  const _EventGrid({required this.events});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: events.length,
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 520,
      mainAxisSpacing: 18,
      crossAxisSpacing: 18,
      childAspectRatio: 0.78,
    ),
    itemBuilder: (_, index) => EventCard(event: events[index]),
  );
}
