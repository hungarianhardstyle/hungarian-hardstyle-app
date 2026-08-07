import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/community_provider.dart';
import '../../providers/voting_provider.dart';
import '../../providers/voting_service_provider.dart';
import '../../providers/news_provider.dart';

class VotingScreen extends ConsumerStatefulWidget {
  const VotingScreen({super.key});

  @override
  ConsumerState<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<VotingScreen> {
  final Map<String, int> _selected = {};
  final Set<String> _voted = {};
  String? _busyCategory;
  bool _newsletterAsked = false;
  bool _newsletterConsent = false;

  Future<void> _vote(dynamic season, dynamic category, dynamic candidate) async {
    if (_busyCategory != null || _voted.contains(category.key)) return;
    final user = ref.read(communityServiceProvider).auth.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A szavazáshoz regisztráció és bejelentkezés szükséges.')));
      return;
    }
    if (!_newsletterAsked) {
      _newsletterConsent = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('HUHS hírlevél'),
              content: const Text('Feliratkozol a Hungarian Hardstyle hírlevelére? A szavazás ettől függetlenül is folytatható.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nem')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Igen')),
              ],
            ),
          ) ??
          false;
      _newsletterAsked = true;
    }
    setState(() => _busyCategory = category.key);
    try {
      await ref.read(votingServiceProvider).submitVote(
            seasonId: season.seasonId,
            category: category.key,
            candidateId: candidate.id,
            newsletterConsent: _newsletterConsent,
            wordpress: ref.read(wordpressServiceProvider),
          );
      if (mounted) setState(() => _voted.add(category.key));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A szavazatod rögzítve.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busyCategory = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voting = ref.watch(votingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('HUHS szavazás')),
      body: voting.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('A szavazás nem tölthető be.\n$error', textAlign: TextAlign.center)),
        data: (season) {
          if (!season.active) return const Center(child: Text('Jelenleg nincs aktív szavazás.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(season.title.isEmpty ? 'HUHS ${season.year} szavazás' : season.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 18),
              for (final category in season.categories) _category(season, category),
            ],
          );
        },
      ),
    );
  }

  Widget _category(dynamic season, dynamic category) {
    final voted = _voted.contains(category.key);
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(category.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (category.candidates.isEmpty) const Text('A jelöltek hamarosan érkeznek.'),
          for (final candidate in category.candidates)
            RadioListTile<int>(
              value: candidate.id,
              groupValue: _selected[category.key],
              onChanged: voted ? null : (value) => setState(() => _selected[category.key] = value ?? 0),
              title: Text(candidate.name),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (candidate.artist.isNotEmpty) Text(candidate.artist),
                if (candidate.spotify.isNotEmpty || candidate.youtube.isNotEmpty)
                  Wrap(spacing: 6, children: [
                    if (candidate.spotify.isNotEmpty) _link('Spotify', candidate.spotify),
                    if (candidate.youtube.isNotEmpty) _link('YouTube', candidate.youtube),
                  ]),
              ]),
            ),
          if (category.candidates.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: voted || _selected[category.key] == null || _busyCategory == category.key
                    ? null
                    : () => _vote(season, category, category.candidates.firstWhere((item) => item.id == _selected[category.key])),
                child: Text(voted ? 'Szavazat rögzítve' : 'Szavazok'),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _link(String label, String value) => OutlinedButton(
        onPressed: () => launchUrl(Uri.tryParse(value) ?? Uri(), mode: LaunchMode.externalApplication),
        child: Text(label),
      );
}
