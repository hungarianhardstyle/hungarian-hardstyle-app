import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../providers/events_provider.dart';
import '../../providers/community_provider.dart';
import '../../models/event.dart';
import '../../widgets/app_text.dart';
import '../../widgets/content_refresh_icon.dart';
import '../../widgets/event_card.dart';
import '../../widgets/huhs_corner_logo.dart';
import '../../services/submission_rules.dart';
import '../../services/wordpress_service.dart';
import 'event_submission_screen.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  static const _eventPageSize = 12;
  final _extraUpcoming = <HuhsEvent>[];
  final _extraPast = <HuhsEvent>[];
  int _upcomingPage = 1;
  int _pastPage = 1;
  bool _hasMoreUpcoming = false;
  bool _hasMorePast = false;
  bool _loadingMoreUpcoming = false;
  bool _loadingMorePast = false;

  void _openSubmission(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const EventSubmissionScreen(),
      ),
    );
  }

  List<HuhsEvent> _mergeEvents(List<HuhsEvent> first, List<HuhsEvent> second) {
    final merged = <HuhsEvent>[];
    final ids = <int>{};
    for (final event in [...first, ...second]) {
      if (ids.add(event.id)) merged.add(event);
    }
    return merged;
  }

  Future<void> _loadMore({required bool past}) async {
    if (past ? _loadingMorePast : _loadingMoreUpcoming) return;
    final nextPage = (past ? _pastPage : _upcomingPage) + 1;
    setState(() {
      if (past) {
        _loadingMorePast = true;
      } else {
        _loadingMoreUpcoming = true;
      }
    });
    try {
      final result = await WordpressService().getEventsPage(
        includePast: past,
        page: nextPage,
        perPage: _eventPageSize,
      );
      if (!mounted) return;
      setState(() {
        if (past) {
          _pastPage = result.page;
          _extraPast
            ..clear()
            ..addAll(_mergeEvents(_extraPast, result.items));
          _hasMorePast = result.hasMore;
          _loadingMorePast = false;
        } else {
          _upcomingPage = result.page;
          _extraUpcoming
            ..clear()
            ..addAll(_mergeEvents(_extraUpcoming, result.items));
          _hasMoreUpcoming = result.hasMore;
          _loadingMoreUpcoming = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (past) {
          _loadingMorePast = false;
        } else {
          _loadingMoreUpcoming = false;
        }
      });
    }
  }

  /// Forced refresh shared by pull-to-refresh and the header refresh icon.
  Future<void> _refreshEvents() async {
    _extraUpcoming.clear();
    _extraPast.clear();
    _upcomingPage = 1;
    _pastPage = 1;
    _hasMoreUpcoming = false;
    _hasMorePast = false;
    final service = WordpressService();
    await Future.wait([
      service.getEvents(forceRefresh: true),
      service.getEvents(includePast: true, forceRefresh: true),
    ]);
    ref.invalidate(eventsProvider);
    ref.invalidate(pastEventsProvider);
    await Future.wait<void>([
      ref.read(eventsProvider.future).then<void>((_) {}),
      ref.read(pastEventsProvider.future).then<void>((_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    final pastEvents = ref.watch(pastEventsProvider);
    final user = ref.watch(communityAuthProvider).valueOrNull;
    final service = ref.watch(communityServiceProvider);
    // Eseményt a tulajdonos szabálya szerint csak SZERVEZŐ (vagy admin)
    // küldhet be — ugyanaz a szabály, mint a szerveren (`SubmissionRules`).
    final canSubmit = SubmissionRules.canSubmit(
      kind: 'event',
      registered: user != null && !user.isAnonymous,
      role: service.cachedAccountRole,
      isAdmin: service.isAdmin,
    );

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
            onRefresh: _refreshEvents,
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
                    onRefresh: _refreshEvents,
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
                    onRefresh: _refreshEvents,
                  ),
                  const SizedBox(height: 80),
                  const AppText(
                    'Nem sikerült betölteni az eseményeket.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => ref.invalidate(eventsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const AppText('Újrapróbálás'),
                    ),
                  ),
                ],
              ),
              data: (items) {
                final mergedItems = _mergeEvents(items, _extraUpcoming);
                final mergedPast = _mergeEvents(
                  pastEvents.valueOrNull ?? const [],
                  _extraPast,
                );
                final canLoadUpcoming =
                    _hasMoreUpcoming || items.length >= _eventPageSize;
                final canLoadPast =
                    _hasMorePast ||
                    (pastEvents.valueOrNull?.length ?? 0) >= _eventPageSize;
                final pastSection = _PastEventsSection(
                  events: mergedPast,
                  hasMore: canLoadPast,
                  loadingMore: _loadingMorePast,
                  onLoadMore: () => _loadMore(past: true),
                );
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
                        onRefresh: _refreshEvents,
                      ),
                      const SizedBox(height: 80),
                      const Center(
                        child: AppText(
                          'Nincs közelgő esemény.',
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ),
                      pastSection,
                    ],
                  );
                }

                final featured = mergedItems
                    .where((event) => event.featured)
                    .toList();
                final regular = mergedItems
                    .where((event) => !event.featured)
                    .toList();
                final landscape =
                    MediaQuery.orientationOf(context) == Orientation.landscape;
                final sections = <Widget>[
                  _EventsHeader(
                    onSubmit: () => _openSubmission(context),
                    showSubmit: canSubmit,
                    onRefresh: _refreshEvents,
                  ),
                  if (featured.isNotEmpty) ...[
                    _EventsSectionTitle(tr(context, 'Kiemelt események')),
                    ...featured.map((event) => EventCard(event: event)),
                  ],
                  if (regular.isNotEmpty) ...[
                    _EventsSectionTitle(tr(context, 'Események')),
                    ...regular.map((event) => EventCard(event: event)),
                  ],
                  if (canLoadUpcoming)
                    _LoadMoreEventsButton(
                      loading: _loadingMoreUpcoming,
                      onPressed: () => _loadMore(past: false),
                    ),
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
                      _EventsSectionTitle(tr(context, 'Kiemelt események')),
                      _EventGrid(events: featured),
                    ],
                    if (regular.isNotEmpty) ...[
                      _EventsSectionTitle(tr(context, 'Események')),
                      _EventGrid(events: regular),
                    ],
                    if (canLoadUpcoming)
                      _LoadMoreEventsButton(
                        loading: _loadingMoreUpcoming,
                        onPressed: () => _loadMore(past: false),
                      ),
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

  const _EventsHeader({
    required this.onSubmit,
    required this.showSubmit,
    required this.onRefresh,
  });

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: AppText(
                'Események',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            ContentRefreshIcon(onRefresh: onRefresh),
            const HuhsCornerLogo(),
          ],
        ),
        const SizedBox(height: 14),
        if (showSubmit)
          OutlinedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add_circle_outline),
            label: const AppText('Esemény beküldése'),
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
  final List<HuhsEvent> events;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;

  const _PastEventsSection({
    required this.events,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const AppText('Korábbi események'),
      subtitle: Text('${events.length}${hasMore ? '+' : ''} lejárt esemény'),
      children: [
        for (final event in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EventCard(event: event),
          ),
        if (hasMore)
          _LoadMoreEventsButton(loading: loadingMore, onPressed: onLoadMore),
      ],
    );
  }
}

class _LoadMoreEventsButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _LoadMoreEventsButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more),
      label: Text(loading ? 'Betöltés…' : tr(context, 'További események')),
    ),
  );
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
