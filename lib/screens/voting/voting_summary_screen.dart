import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/i18n/tr.dart';
import '../../models/voting.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_text.dart';

class VotingSummaryScreen extends ConsumerStatefulWidget {
  const VotingSummaryScreen({super.key});

  @override
  ConsumerState<VotingSummaryScreen> createState() =>
      _VotingSummaryScreenState();
}

class _VotingSummaryScreenState extends ConsumerState<VotingSummaryScreen> {
  late Future<List<VotingSeason>> _seasonsFuture;
  VotingSeason? _selectedSeason;
  Future<Map<String, dynamic>>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _seasonsFuture = _loadSeasons();
  }

  Future<List<VotingSeason>> _loadSeasons() async {
    final response = await ref
        .read(communityServiceProvider)
        .wordPressAdminRequest(path: '/huhs/v1/admin?action=voting_seasons');
    final raw = response is Map ? response['seasons'] : null;
    final seasons = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) =>
                    VotingSeason.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((season) => season.seasonId > 0)
              .toList(growable: false)
        : const <VotingSeason>[];
    if (seasons.isEmpty) throw StateError('Nincs elérhető szavazási szezon.');
    return seasons;
  }

  Future<Map<String, dynamic>> _loadSummary(VotingSeason season) async {
    final result = await ref
        .read(communityServiceProvider)
        .wordPressAdminRequest(
          path:
              '/huhs/v1/admin?action=voting_summary&seasonId=${season.seasonId}',
        );
    if (result is! Map) throw StateError('Az összesítő válasza érvénytelen.');
    return Map<String, dynamic>.from(result);
  }

  void _refresh() {
    ref.read(communityServiceProvider).clearAdminCache();
    setState(() {
      _selectedSeason = null;
      _summaryFuture = null;
      _seasonsFuture = _loadSeasons();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Szavazási összesítő'),
        actions: [
          IconButton(
            tooltip: tr(context, 'Frissítés'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<VotingSeason>>(
        future: _seasonsFuture,
        builder: (context, seasonsSnapshot) {
          if (seasonsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (seasonsSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  userFacingError(seasonsSnapshot.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final seasons = seasonsSnapshot.data ?? const <VotingSeason>[];
          if (seasons.isEmpty) {
            return const Center(
              child: AppText('Nincs elérhető szavazási szezon.'),
            );
          }

          final selected = _selectedSeason ??= seasons.first;
          _summaryFuture ??= _loadSummary(selected);
          return FutureBuilder<Map<String, dynamic>>(
            future: _summaryFuture,
            builder: (context, summarySnapshot) {
              if (summarySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (summarySnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      userFacingError(summarySnapshot.error!),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final summary = summarySnapshot.data ?? const <String, dynamic>{};
              final summarySeason = _seasonFromSummary(summary);
              // The summary endpoint is the source of truth for the selected
              // season. The seasons endpoint can be cached or return only
              // selector metadata, which previously left this screen empty.
              final displaySeason =
                  summarySeason != null &&
                      summarySeason.seasonId == selected.seasonId &&
                      summarySeason.categories.isNotEmpty
                  ? summarySeason
                  : selected;
              final counts = <String, int>{};
              final rawCounts = summary['counts'];
              if (rawCounts is Map) {
                rawCounts.forEach((key, value) {
                  final parsed = value is num
                      ? value.toInt()
                      : int.tryParse('$value');
                  if (parsed != null) counts['$key'] = parsed;
                });
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _seasonSelector(context, seasons, selected),
                  const SizedBox(height: 16),
                  Text(
                    trArgs(context, 'Összes leadott szavazat: {n}', {
                      'n': '${summary['totalVotes'] ?? 0}',
                    }),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (displaySeason.hasPublishedResults)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(displaySeason.resultsUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const AppText('Nyilvános eredmények megnyitása'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (displaySeason.categories.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: AppText(
                          'Ehhez az évadhoz nem érkezett kategóriaadat.',
                        ),
                      ),
                    ),
                  for (final category in displaySeason.categories)
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
                            const SizedBox(height: 6),
                            for (
                              var index = 0;
                              index <
                                  _sortedCandidates(category, counts).length;
                              index++
                            )
                              Builder(
                                builder: (context) {
                                  final candidate = _sortedCandidates(
                                    category,
                                    counts,
                                  )[index];
                                  final votes = _countFor(
                                    category,
                                    candidate,
                                    counts,
                                  );
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${index + 1}.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge,
                                      ),
                                    ),
                                    title: Text(
                                      candidate.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: candidate.artist.trim().isEmpty
                                        ? null
                                        : Text(
                                            candidate.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    trailing: Text(
                                      '$votes szavazat',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  VotingSeason? _seasonFromSummary(Map<String, dynamic> summary) {
    final rawSeason = summary['season'];
    final season = rawSeason is Map
        ? Map<String, dynamic>.from(rawSeason)
        : <String, dynamic>{};
    final rawCategories = summary['categories'] ?? summary['categoryResults'];
    if (season['categories'] == null && rawCategories != null) {
      season['categories'] = rawCategories;
    }
    if (season.isEmpty) return null;
    return VotingSeason.fromJson(season);
  }

  Widget _seasonSelector(
    BuildContext context,
    List<VotingSeason> seasons,
    VotingSeason selected,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: tr(context, 'Szavazási évad'),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final nextId = await showModalBottomSheet<int>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: AppText(
                        'Szavazási évad kiválasztása',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final season in seasons)
                      ListTile(
                        leading: Icon(
                          season.seasonId == selected.seasonId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(
                          _seasonLabel(season),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () =>
                            Navigator.pop(sheetContext, season.seasonId),
                      ),
                  ],
                ),
              ),
            ),
          );
          if (!mounted || nextId == null || nextId == selected.seasonId) {
            return;
          }
          final next = seasons.firstWhere(
            (season) => season.seasonId == nextId,
          );
          setState(() {
            _selectedSeason = next;
            _summaryFuture = _loadSummary(next);
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _seasonLabel(selected),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }

  String _seasonLabel(VotingSeason season) {
    final year = season.year > 0 ? '${season.year} · ' : '';
    final title = season.title.trim();
    return title.isEmpty ? year.trim() : '$year$title';
  }

  int _countFor(
    VotingCategory category,
    VotingCandidate candidate,
    Map<String, int> counts,
  ) => counts['${category.key}:${candidate.id}'] ?? 0;

  List<VotingCandidate> _sortedCandidates(
    VotingCategory category,
    Map<String, int> counts,
  ) {
    final candidates = [...category.candidates];
    candidates.sort((a, b) {
      final countA = _countFor(category, a, counts);
      final countB = _countFor(category, b, counts);
      final byVotes = countB.compareTo(countA);
      return byVotes != 0
          ? byVotes
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return candidates;
  }
}
