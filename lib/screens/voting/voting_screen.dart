import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/tr.dart';
import '../../models/voting.dart';
import '../../providers/community_provider.dart';
import '../../providers/voting_provider.dart';
import '../../providers/voting_service_provider.dart';
import '../../providers/news_provider.dart';
import '../../services/voting_service.dart';
import '../../widgets/app_text.dart';

class VotingScreen extends ConsumerStatefulWidget {
  const VotingScreen({super.key});

  @override
  ConsumerState<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<VotingScreen> {
  final Map<String, Set<int>> _selected = {};
  final Set<String> _voted = {};
  int? _statusSeasonId;
  bool _loadingVoteStatus = false;
  bool _ballotSubmitted = false;
  bool _busy = false;
  bool _newsletterAsked = false;
  bool _newsletterConsent = false;

  void _ensureVoteStatus(VotingSeason season) {
    if (!season.active ||
        _statusSeasonId == season.seasonId ||
        _loadingVoteStatus) {
      return;
    }
    _statusSeasonId = season.seasonId;
    _loadingVoteStatus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = ref.read(votingServiceProvider);
      final cachedFuture = service.cachedVotingStatus(
        seasonId: season.seasonId,
      );
      final serverFuture = service.votingStatus(seasonId: season.seasonId);

      try {
        final cached = await cachedFuture;
        if (mounted && cached != null && _statusSeasonId == season.seasonId) {
          setState(() {
            _applyVotingStatus(cached, season);
          });
        }
      } catch (_) {
        // A corrupt or unavailable local cache must not block the server read.
      }

      try {
        final status = await serverFuture;
        try {
          await service.cacheVotingStatus(
            seasonId: season.seasonId,
            status: status,
          );
        } catch (_) {
          // The cache is optional and must not affect the server result.
        }
        if (mounted) {
          setState(() {
            _applyVotingStatus(status, season);
          });
        }
      } catch (_) {
        // The server still prevents duplicate votes if this optional lookup
        // is temporarily unavailable.
      } finally {
        _loadingVoteStatus = false;
      }
    });
  }

  void _applyVotingStatus(VotingStatus status, VotingSeason season) {
    _voted
      ..clear()
      ..addAll(status.votedCategories);
    for (final category in season.categories) {
      if (!status.votedCategories.contains(category.key)) {
        _selected.remove(category.key);
        continue;
      }
      final selected = status.selectedCandidateIds[category.key];
      if (selected != null) {
        _selected[category.key] = {...selected};
      }
    }
    _ballotSubmitted = season.categories.every(
      (category) => status.votedCategories.contains(category.key),
    );
  }

  Future<void> _voteAll(VotingSeason season) async {
    if (_busy) return;
    final missing = season.categories
        .where(
          (category) =>
              !_voted.contains(category.key) &&
              (_selected[category.key]?.length ?? 0) != category.minVotes,
        )
        .toList(growable: false);
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Még hiányzik:\n${missing.map((category) => '${category.label}: ${category.minVotes} választás').join('\n')}',
          ),
        ),
      );
      return;
    }
    final votes = <String, List<int>>{};
    for (final category in season.categories) {
      if (_voted.contains(category.key)) continue;
      votes[category.key] = (_selected[category.key] ?? const <int>{}).toList();
    }
    if (votes.isEmpty) return;
    final user = ref.read(communityServiceProvider).auth.currentUser;
    if (!_newsletterAsked && user != null && !user.isAnonymous) {
      _newsletterConsent =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const AppText('HUHS hírlevél'),
              content: const AppText(
                'Feliratkozol a Hungarian Hardstyle hírlevelére? A szavazás ettől függetlenül is folytatható.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const AppText('Nem'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const AppText('Igen'),
                ),
              ],
            ),
          ) ??
          false;
      _newsletterAsked = true;
    }
    setState(() => _busy = true);
    try {
      final service = ref.read(votingServiceProvider);
      await service.submitBallot(
        seasonId: season.seasonId,
        votes: votes,
        newsletterConsent: _newsletterConsent,
        wordpress: ref.read(wordpressServiceProvider),
      );
      _voted.addAll(votes.keys);
      try {
        await service.cacheVotingStatus(
          seasonId: season.seasonId,
          status: VotingStatus(
            votedCategories: {..._voted},
            selectedCandidateIds: {
              for (final entry in _selected.entries)
                entry.key: {...entry.value},
            },
          ),
        );
      } catch (_) {
        // The vote was already accepted by the server; caching is optional.
      }
      if (mounted) {
        setState(() {
          _ballotSubmitted = true;
        });
      }
      if (mounted) await _showVoteSuccessDialog();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'A szavazat mentése nem sikerült. Próbáld újra később.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voting = ref.watch(votingProvider);
    return Scaffold(
      appBar: AppBar(title: const AppText('HUHS szavazás')),
      body: voting.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: AppText(
            'A szavazás jelenleg nem tölthető be. Próbáld újra később.',
            textAlign: TextAlign.center,
          ),
        ),
        data: (season) {
          _ensureVoteStatus(season);
          if (!season.active) {
            return Center(
              child: season.hasPublishedResults
                  ? FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(season.resultsUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.poll_outlined),
                      label: const AppText('Eredmények megtekintése'),
                    )
                  : season.isClosed
                  ? const AppText(
                      'A szavazás véget ért. Az összesítő az adminisztrátori engedély után lesz elérhető.',
                      textAlign: TextAlign.center,
                    )
                  : const AppText('Jelenleg nincs aktív szavazás.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                season.title.isEmpty
                    ? 'HUHS ${season.year} szavazás'
                    : season.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              AppText(
                'Regisztráció nélkül is szavazhatsz. Egy készülékről ebben az évadban csak egyszer lehet leadni a szavazatot.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              for (final category in season.categories)
                _category(season, category),
              _ballotAction(season),
            ],
          );
        },
      ),
    );
  }

  Widget _category(VotingSeason season, VotingCategory category) {
    final voted = _ballotSubmitted;
    final selected = _selected[category.key] ?? const <int>{};
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category.label, style: Theme.of(context).textTheme.titleLarge),
            Text(
              'Válassz pontosan ${category.minVotes} jelöltet (${selected.length}/${category.minVotes})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (category.candidates.isEmpty)
              const AppText('A jelöltek hamarosan érkeznek.'),
            if (category.key == 'international_dj')
              _internationalPicker(category, voted, selected)
            else
              for (final candidate in category.candidates)
                CheckboxListTile(
                  value: selected.contains(candidate.id),
                  activeColor: Theme.of(context).colorScheme.primary,
                  checkColor: Theme.of(context).colorScheme.onPrimary,
                  onChanged: voted
                      ? null
                      : (value) {
                          final next = {...selected};
                          if (value == true) {
                            if (next.length >= category.maxVotes) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Legfeljebb ${category.maxVotes} jelöltet választhatsz.',
                                  ),
                                ),
                              );
                              return;
                            }
                            next.add(candidate.id);
                          } else {
                            next.remove(candidate.id);
                          }
                          setState(() => _selected[category.key] = next);
                        },
                  title: Text(candidate.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (candidate.artist.isNotEmpty) Text(candidate.artist),
                      if (candidate.spotify.isNotEmpty ||
                          candidate.youtube.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children: [
                            if (candidate.spotify.isNotEmpty)
                              _link('Spotify', candidate.spotify),
                            if (candidate.youtube.isNotEmpty)
                              _link('YouTube', candidate.youtube),
                          ],
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _ballotAction(VotingSeason season) {
    final missing = season.categories
        .where(
          (category) =>
              !_voted.contains(category.key) &&
              (_selected[category.key]?.length ?? 0) != category.minVotes,
        )
        .toList(growable: false);
    final remaining = season.categories.any(
      (category) => !_voted.contains(category.key),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadingVoteStatus) const LinearProgressIndicator(minHeight: 2),
            if (missing.isNotEmpty)
              Text(
                'A szavazás elküldéséhez minden kötelező kategóriát ki kell tölteni.\n\n${missing.map((category) => '• ${category.label}: ${category.minVotes} jelölt').join('\n')}',
              )
            else if (!remaining)
              const AppText('Minden kategóriában leadtad a szavazatodat.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || missing.isNotEmpty || !remaining
                  ? null
                  : () => _voteAll(season),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.how_to_vote_outlined),
              label: const AppText('Szavazok'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVoteSuccessDialog() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const AppText('Köszönjük a szavazatod!'),
      content: const AppText(
        'A szavazatod sikeresen rögzítettük. Ebben az éves szavazásban erről a készülékről már nem adhatsz le újabb szavazatot.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const AppText('Bezárás'),
        ),
      ],
    ),
  );

  Widget _internationalPicker(
    VotingCategory category,
    bool voted,
    Set<int> selected,
  ) {
    final selectedCandidates = category.candidates
        .where((candidate) => selected.contains(candidate.id))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: voted ? null : () => _chooseInternational(category),
          icon: const Icon(Icons.arrow_drop_down),
          label: Text(
            selected.isEmpty
                ? 'Külföldi DJ-k kiválasztása'
                : '${selected.length} kiválasztva',
          ),
        ),
        if (selectedCandidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppText(
            'Kiválasztott jelöltek:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final candidate in selectedCandidates)
                Chip(
                  label: Text(candidate.name),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _chooseInternational(dynamic category) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // The app scaffold is intentionally transparent for the branded
      // background.  A modal picker must remain opaque, otherwise the voting
      // cards underneath bleed through and the list becomes unreadable.
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        var query = '';
        var selected = {...?_selected[category.key]};
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final candidates = (category.candidates as List<VotingCandidate>)
                .where(
                  (VotingCandidate candidate) => candidate.name
                      .toLowerCase()
                      .contains(query.trim().toLowerCase()),
                );
            return Material(
              color: Theme.of(context).colorScheme.surface,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .86,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              'Külföldi hardstyle DJ-k',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: tr(context, 'Bezárás'),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: tr(context, 'Keresés név szerint'),
                        ),
                        onChanged: (value) =>
                            setDialogState(() => query = value),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppText(
                          trArgs(context, 'Kiválasztva: {n}/5', {
                            'n': '${selected.length}',
                          }),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListView.builder(
                          itemCount: candidates.length,
                          itemBuilder: (context, index) {
                            final candidate = candidates.elementAt(index);
                            return CheckboxListTile(
                              dense: true,
                              value: selected.contains(candidate.id),
                              title: Text(candidate.name),
                              onChanged: (value) {
                                final next = {...selected};
                                if (value == true && next.length >= 5) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: AppText(
                                        'Pontosan 5 jelölt választható.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                value == true
                                    ? next.add(candidate.id)
                                    : next.remove(candidate.id);
                                setDialogState(() => selected = next);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: selected.length == 5
                              ? () => Navigator.pop(context, selected)
                              : null,
                          child: const AppText('Kiválasztás'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _selected[category.key] = result);
    }
  }

  Widget _link(String label, String value) => OutlinedButton(
    onPressed: () => launchUrl(
      Uri.tryParse(value) ?? Uri(),
      mode: LaunchMode.externalApplication,
    ),
    child: Text(label),
  );
}
