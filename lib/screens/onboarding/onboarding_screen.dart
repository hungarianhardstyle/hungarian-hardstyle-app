import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/tr.dart';
import '../../models/artist.dart';
import '../../providers/artists_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/genre_preferences_provider.dart';
import '../../services/onboarding_plan.dart';
import '../../services/onboarding_state.dart';
import '../../widgets/notification_permission_prompt.dart';
import '../../widgets/resized_network_image.dart';
import '../community/community_screen.dart';

/// **Onboarding — 5 lépés (408)**: bemutatás → stílusok → DJ-k követése helyben
/// → belépés (mit ad) → értesítések.
///
/// MIÉRT: a mért szakadék a **regisztrált profilok** és a **push-ra regisztrált
/// eszközök** között van. A régi 3 lépéses változat a DJ-követést csak
/// elmagyarázta; ez **helyben** követteti őket, a stílusok szerint sorba rakva.
///
/// ⚠️ Egyszer fut és **átugorható**; a „Kész" és a „Kihagyás" is lezárja
/// (`markOnboardingCompleted`). Vendégként a követés **helyben** mentődik, és a
/// belépéskor a kedvencekbe kerül (`applyPendingArtistFollows`).
///
/// ⚠️ A feliratok **közvetlenül** a `tr(context, '…')` hívásban állnak: az i18n
/// extraktor csak így látja őket.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const String routeName = '/onboarding';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const ArtistListQuery _allArtists = (category: '', search: '');

  OnboardingStep _step = OnboardingStep.welcome;
  final Set<String> _genres = <String>{};
  Map<int, String> _pendingFollows = const {};
  bool _loadedPrefs = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _genres.addAll(preferredGenresFromPreferences(prefs));
        _pendingFollows = pendingArtistFollowsFromPreferences(prefs);
        _loadedPrefs = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loadedPrefs = true);
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await savePreferredGenres(prefs, _genres);
    markOnboardingCompleted(prefs);
    ref.invalidate(preferredGenresProvider);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _next() async {
    if (_step == OnboardingStep.genres) {
      await savePreferredGenres(await SharedPreferences.getInstance(), _genres);
      ref.invalidate(preferredGenresProvider);
    }
    final next = nextOnboardingStep(_step);
    if (next == null) {
      await _finish();
      return;
    }
    if (mounted) setState(() => _step = next);
  }

  bool _isFollowed(FavoritesNotifier favorites, int id) =>
      favorites.contains(FavoriteKind.artist, id) ||
      _pendingFollows.containsKey(id);

  Future<void> _toggleFollow(FavoritesNotifier favorites, Artist artist) async {
    if (favorites.canUseFavorites) {
      await favorites.toggle(FavoriteKind.artist, artist.id, artist.title);
      if (_pendingFollows.containsKey(artist.id)) {
        final next = Map<int, String>.of(_pendingFollows)..remove(artist.id);
        await savePendingArtistFollows(
          await SharedPreferences.getInstance(),
          next,
        );
        if (mounted) setState(() => _pendingFollows = next);
      }
      return;
    }
    final next = Map<int, String>.of(_pendingFollows);
    if (next.containsKey(artist.id)) {
      next.remove(artist.id);
    } else {
      next[artist.id] = artist.title;
    }
    setState(() => _pendingFollows = next);
    await savePendingArtistFollows(await SharedPreferences.getInstance(), next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Üdv a Hungarian Hardstyle appban')),
        actions: [
          TextButton(onPressed: _finish, child: Text(tr(context, 'Kihagyás'))),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: onboardingStepNumber(_step) / onboardingStepCount,
          ),
          Expanded(child: _buildStep(context)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding-next'),
                  onPressed: _next,
                  child: Text(
                    _step == OnboardingStep.notifications
                        ? tr(context, 'Kész')
                        : _step == OnboardingStep.account &&
                              ref.watch(currentUidProvider) == null
                        ? tr(context, 'Később')
                        : tr(context, 'Tovább'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case OnboardingStep.welcome:
        return _welcome(context);
      case OnboardingStep.genres:
        return _genreStep(context);
      case OnboardingStep.favoriteArtists:
        return _artistStep(context);
      case OnboardingStep.account:
        return _accountStep(context);
      case OnboardingStep.notifications:
        return _notificationStep(context);
    }
  }

  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    Widget feature(IconData icon, String label) => ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Image.asset(
            'assets/logos/huhs_logo.png',
            height: 120,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          tr(context, 'Minden, ami a színtéren történik'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            context,
            'Néhány lépésben személyessé tesszük: a stílusod alapján ajánlunk DJ-ket és bulikat.',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        feature(
          Icons.newspaper,
          tr(context, 'Friss hírek a hazai és külföldi színtérről'),
        ),
        feature(
          Icons.event,
          tr(context, 'Közelgő bulik, jegyek és helyszínek'),
        ),
        feature(
          Icons.radio,
          tr(context, 'Real Hardstyle FM rádió a háttérben is'),
        ),
        feature(
          Icons.forum_outlined,
          tr(context, 'Chat és közösség a ravereknek'),
        ),
      ],
    );
  }

  Widget _stepHeader(BuildContext context, String title, String body) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      );

  Widget _genreStep(BuildContext context) {
    final artists = ref.watch(artistsProvider(_allArtists));
    final genres = availableGenres(
      (artists.valueOrNull?.items ?? const <Artist>[]).map((a) => a.genres),
    );
    return ListView(
      children: [
        _stepHeader(
          context,
          tr(context, 'Mit szeretsz hallgatni?'),
          tr(
            context,
            'Jelöld be a kedvenc stílusaidat — ez alapján ajánlunk. Bármikor kihagyhatod.',
          ),
        ),
        if (artists.isLoading && genres.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (genres.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr(
                context,
                'A stílusokat most nem sikerült betölteni, ezt a lépést kihagyhatod.',
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in genres)
                  FilterChip(
                    label: Text(genre),
                    selected: _genres.any(
                      (g) => normalizeGenre(g) == normalizeGenre(genre),
                    ),
                    onSelected: (selected) => setState(() {
                      _genres.removeWhere(
                        (g) => normalizeGenre(g) == normalizeGenre(genre),
                      );
                      if (selected) _genres.add(genre);
                    }),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _artistStep(BuildContext context) {
    final artists = ref.watch(artistsProvider(_allArtists));
    final favorites = ref.watch(favoritesProvider);
    final ranked = rankByGenres<Artist>(
      artists.valueOrNull?.items ?? const <Artist>[],
      (artist) => artist.genres,
      _genres,
    );
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return ListView(
      children: [
        _stepHeader(
          context,
          tr(context, 'Kövesd a kedvenc DJ-jeidet'),
          tr(
            context,
            'Koppints a követéshez: szólunk, ha új kiadványuk vagy bulijuk van.',
          ),
        ),
        if (!_loadedPrefs || (artists.isLoading && ranked.isEmpty))
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (ranked.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr(
                context,
                'A DJ-ket most nem sikerült betölteni, később a DJ-k listájában követheted őket.',
              ),
            ),
          )
        else
          for (final artist in ranked)
            CheckboxListTile(
              key: Key('onboarding-artist-${artist.id}'),
              value: _isFollowed(favorites, artist.id),
              onChanged: (_) => _toggleFollow(favorites, artist),
              secondary: CircleAvatar(
                child: ClipOval(
                  child: () {
                    final url = artist.profileImageUrl.isNotEmpty
                        ? artist.profileImageUrl
                        : artist.logoUrl;
                    if (url.isEmpty) return const Icon(Icons.person);
                    return ResizedNetworkImage(
                      url: url,
                      physicalWidth: (40 * ratio).round(),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.5),
                      errorWidget: (_, _, _) => const Icon(Icons.person),
                    );
                  }(),
                ),
              ),
              title: Text(artist.title),
              subtitle: artist.genres.isEmpty
                  ? null
                  : Text(
                      artist.genres.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
      ],
    );
  }

  Widget _accountStep(BuildContext context) {
    final signedIn = ref.watch(currentUidProvider) != null;
    final theme = Theme.of(context);
    Widget benefit(IconData icon, String label) => ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
    );
    return ListView(
      children: [
        _stepHeader(
          context,
          signedIn
              ? tr(context, 'Be vagy jelentkezve')
              : tr(context, 'Lépj be, és minden megmarad'),
          signedIn
              ? tr(
                  context,
                  'A követéseid és a kedvenceid a fiókodhoz mentődnek.',
                )
              : tr(
                  context,
                  'A belépés ingyenes és átugorható. Belépve ezt kapod:',
                ),
        ),
        if (!signedIn) ...[
          benefit(
            Icons.favorite_outline,
            tr(context, 'A követett DJ-k minden eszközödön megmaradnak'),
          ),
          benefit(
            Icons.forum_outlined,
            tr(context, 'Írhatsz a Chatbe és kommentelhetsz'),
          ),
          benefit(
            Icons.emoji_events_outlined,
            tr(context, 'Achievement-pontokat és jelvényeket gyűjthetsz'),
          ),
          benefit(
            Icons.event_available,
            tr(context, 'Jelezheted, melyik bulin leszel ott'),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: OutlinedButton.icon(
              key: const Key('onboarding-sign-in'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CommunityProfileScreen(),
                  ),
                );
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.login),
              label: Text(tr(context, 'Belépés vagy regisztráció')),
            ),
          ),
          if (_pendingFollows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                trArgs(
                  context,
                  'A {n} követett DJ-t a belépés után a fiókodba mentjük.',
                  {'n': '${_pendingFollows.length}'},
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _notificationStep(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final names = <String>{
      ...favorites.entries
          .where((entry) => entry.kind == FavoriteKind.artist)
          .map((entry) => entry.title),
      ..._pendingFollows.values,
    }.where((name) => name.trim().isNotEmpty).toList();
    final shown = names.take(3).join(', ');
    return ListView(
      children: [
        _stepHeader(
          context,
          tr(context, 'Ne maradj le semmiről'),
          names.isEmpty
              ? tr(
                  context,
                  'Szólunk, ha a kedvelt DJ-d új kiadványt tesz közzé, ha közelgő buli van, és vasárnap a hét összefoglalójával.',
                )
              : trArgs(
                  context,
                  'Szólunk, ha {names} új kiadványt tesz közzé vagy bulin játszik, és vasárnap a hét összefoglalójával.',
                  {'names': names.length > 3 ? '$shown…' : shown},
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: OutlinedButton.icon(
            onPressed: () =>
                NotificationPermissionPrompt.requestAfterAction(context),
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(tr(context, 'Értesítések engedélyezése')),
          ),
        ),
      ],
    );
  }
}
