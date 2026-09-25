import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../models/poll.dart';
import '../../providers/community_provider.dart';
import '../../providers/poll_provider.dart';
import '../../services/vote_memory.dart';
import '../../widgets/app_text.dart';
import '../../widgets/brand_loading_indicator.dart';
import '../../widgets/content_refresh_icon.dart';
import 'poll_results_screen.dart';

/// Kozvelemenykutatas - a kerdőív sajat képernyője.
///
/// A főoldalon csak egy gomb jelzi a nyitott kerdőívet (lasd
/// `PollEntryButton`); maga a szavazas ide kerul, mert a valaszlehetosegek
/// listaja es a „Szavazok" gomb így nem nyomja el a hírfolyamot.
///
/// A kerdőív adatat a hivo adja at (`poll`), ezert a képernyő nem indit
/// ujabb hálózati kérést a kerdesert. A „szavaztal mar?" allapot viszont
/// **frissen** kerdődik le (`hasVotedProvider`), mert az valtozhatott: a
/// felhasznalo szavazhatott a weblapon, vagy egy korabbi munkamenetben.
///
/// Csak regisztralt fiok szavazhat; vendeget a képernyő figyelmeztet, de a
/// szavazat VEGSO ellenorzese a szerveren van (a `pollVote` callable), ezert a
/// felulet megkerülése sem ad érvényes szavazatot.
class PollScreen extends ConsumerStatefulWidget {
  const PollScreen({super.key, required this.poll});

  final HuhsPoll poll;

  @override
  ConsumerState<PollScreen> createState() => _PollScreenState();
}

class _PollScreenState extends ConsumerState<PollScreen> {
  int? _selected;
  bool _submitting = false;
  bool _voted = false;
  String? _message;

  /// A „szavaztal mar?" allapot ujrakerdezese. A szerver oldali egyediseg
  /// miatt ez sosem ad masodik érvényes szavazatot, csak a feluletet igazitja.
  Future<void> _refreshStatus() async {
    ref.invalidate(hasVotedProvider(widget.poll.id));
    await ref
        .read(hasVotedProvider(widget.poll.id).future)
        .catchError((Object _) => false);
  }

  Future<void> _submit(HuhsPoll poll) async {
    final selected = _selected;
    if (selected == null || _submitting) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final alreadyVoted = await ref
          .read(pollServiceProvider)
          .vote(pollId: poll.id, optionIndex: selected);
      // A most leadott szavazat a legfrissebb ismert allapot: elmentjuk, hogy a
      // kovetkezo megnyitasnal azonnal latszodjon (ne kelljen a szerverre varni).
      await VoteMemory.markPollVoted(
        ref.read(currentUidProvider),
        poll.id,
      );
      if (!mounted) return;
      setState(() {
        _voted = true;
        _submitting = false;
        _message = alreadyVoted ? 'Ebben a kérdőívben már szavaztál.' : null;
      });
      // A most rogzitett szavazat az uj allapot; a mentett valasz frissul.
      ref.invalidate(hasVotedProvider(poll.id));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _message = error is Exception
            ? _readableError(error)
            : 'A szavazatot most nem sikerült rögzíteni. Próbáld újra.';
      });
    }
  }

  String _readableError(Exception error) {
    final text = error.toString();
    if (text.contains('unauthenticated') ||
        text.contains('permission-denied')) {
      return 'A szavazáshoz regisztrált fiók szükséges.';
    }
    if (text.contains('failed-precondition') || text.contains('nem elérhető')) {
      return 'A kérdőív jelenleg nem elérhető.';
    }
    if (text.contains('resource-exhausted')) {
      return 'Túl sok próbálkozás. Próbáld kicsit később.';
    }
    return 'A szavazatot most nem sikerült rögzíteni. Próbáld újra.';
  }

  /// A kérdőív eredmény-összesítője — CSAK adminnak, mert a WordPress
  /// admin-végpont mögött van (publikus eredmény-végpont szándékosan nincs).
  ///
  /// **Ez korábban rossz volt:** a `VotingSummaryScreen`-t nyitotta meg, ami az
  /// ÉVES SZAVAZÁS összesítőjét kéri le, ezért a kérdőívnél a jelöltekre leadott
  /// szavazatok látszottak. A saját `PollResultsScreen` a `poll_results`
  /// műveletet kéri, ami a kérdőív válaszaira adja a számokat.
  void _openResults() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PollResultsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(communityAuthProvider).valueOrNull;
    final registered = user != null && !user.isAnonymous;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Kérdőív'),
        actions: [ContentRefreshIcon(onRefresh: _refreshStatus)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.poll_outlined, size: 20),
                      const SizedBox(width: 8),
                      AppText(
                        'KÉRDŐÍV',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.poll.question,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!registered)
                    const AppText(
                      'A szavazáshoz regisztrált fiók szükséges. Regisztrálj, vagy jelentkezz be, és utána szavazhatsz.',
                    )
                  else
                    _buildStatus(context),
                  if (_message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _message!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Az eredmeny-osszesito a WordPress ADMIN vegpontjarol jon
          // (`/huhs/v1/admin?action=voting_summary`), ezert sima felhasznalonak
          // nincs hozza jogosultsaga — a gombot eddig megis feltetel nelkul
          // kiadtuk szavazas utan, es a felhasznalo hibauzenetet kapott.
          //
          // Mostantol CSAK admin latja, es neki akkor is latszik, ha meg nem
          // szavazott: aki a kerdőívet osszeallitja, annak a szavazas elott is
          // meg kell tudnia nezni, hol tart.
          if (registered &&
              ref.watch(currentUserIsAdminProvider).valueOrNull == true) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openResults,
                icon: const Icon(Icons.bar_chart_outlined, size: 20),
                label: const AppText('Eredmények megtekintése'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    if (_voted) return const _PollThanks();
    final request = ref.watch(hasVotedProvider(widget.poll.id));
    return request.when(
      // A valaszlehetosegek listaja CSAK akkor jelenik meg, ha a szerver
      // kifejezetten azt mondta, hogy ez a fiok meg nem szavazott. Amig a
      // valasz uton van (vagy hibara futott), a lista NEM latszik: egy
      // szavazott felhasznalonak nem szabad ujra valaszlehetosegeket latnia.
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: BrandLoadingIndicator()),
      ),
      error: (_, _) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'A szavazás állapotát most nem sikerült lekérdezni. Ellenőrizd a kapcsolatot, és próbáld újra a jobb felső frissítés ikonnal.',
          ),
        ],
      ),
      data: (voted) =>
          voted ? const _PollThanks() : _buildBallot(context, widget.poll),
    );
  }

  Widget _buildBallot(BuildContext context, HuhsPoll poll) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plain ListTiles instead of RadioListTile: the Material radio API is
        // being migrated to RadioGroup in this Flutter version, and a poll only
        // needs a single selection that is read back once.
        ...poll.options.map(
          (option) => ListTile(
            onTap: _submitting
                ? null
                : () => setState(() => _selected = option.index),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              _selected == option.index
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: _selected == option.index
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(option.label),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _selected == null || _submitting
                ? null
                : () => _submit(poll),
            child: Text(_submitting ? 'Küldés…' : tr(context, 'Szavazok')),
          ),
        ),
        const SizedBox(height: 6),
        const AppText(
          'Egy fiók egyszer szavazhat, a szavazat utólag nem módosítható. Az eredmény nem nyilvános.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
      ],
    );
  }
}

class _PollThanks extends StatelessWidget {
  const _PollThanks();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.check_circle_outline, size: 20),
        SizedBox(width: 8),
        Expanded(child: AppText('Köszönjük, a szavazatod rögzítettük.')),
      ],
    );
  }
}
