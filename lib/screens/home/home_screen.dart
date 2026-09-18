import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/events_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/voting_provider.dart';
import '../../providers/games_provider.dart';
import '../../providers/poll_provider.dart';
import '../../providers/prize_provider.dart';
import '../../models/post.dart';
import '../../models/game.dart';
import '../../widgets/event_card.dart';
import '../../widgets/featured_news_card.dart';
import '../../widgets/mobile_ad_banner.dart';
import '../../widgets/brand_loading_indicator.dart';
import '../../widgets/content_refresh_icon.dart';
import '../../widgets/home_action_card.dart';
import '../../widgets/poll_entry_button.dart';
import '../../widgets/prize_entry_card.dart';
import '../../services/notification_service.dart';
import '../notifications/notification_center_screen.dart';
import '../community/community_screen.dart';
import '../more/community_users_screen.dart';
import '../voting/voting_screen.dart';
import '../games/game_screen.dart';

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Értesítések',
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.notifications_none_rounded, size: 24),
        ),
        if (count > 0)
          Positioned(
            right: 0,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF17090B), width: 2),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HomeScreen extends ConsumerWidget {
  final VoidCallback onShowMoreNews;

  const HomeScreen({super.key, required this.onShowMoreNews});

  /// Forced refresh shared by pull-to-refresh and the header refresh icon.
  Future<void> _refreshHome(WidgetRef ref) async {
    ref.invalidate(newsProvider);
    ref.invalidate(eventsProvider);
    // A kerdőív is frissul: nyitas/zaras utan a kartyanak követnie kell.
    ref.invalidate(activePollProvider);
    // A nyeremenyjatek ugyanígy: a jatek nyitasa, zarasa es a sorsolas is
    // időponthoz kotott, ezert a frissitesnek ezt is le kell kérdeznie.
    ref.invalidate(activePrizeProvider);
    await Future.wait<void>([
      ref.read(newsProvider.future),
      ref.read(eventsProvider.future),
      // A kerdőív opcionalis, ezert egy hibaja ne törje meg a frissitést.
      ref.read(activePollProvider.future).catchError((Object _) => null),
      // Ugyanez a nyeremenyjatekra.
      ref.read(activePrizeProvider.future).catchError((Object _) => null),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(newsProvider);
    final events = ref.watch(eventsProvider);
    final activeGame = ref.watch(activeGameProvider);
    final latestGameResults = ref.watch(latestGameResultsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refreshHome(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CommunityAvatarButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CommunityProfileScreen(),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ContentRefreshIcon(
                              onRefresh: () => _refreshHome(ref),
                            ),
                            StreamBuilder(
                              stream: Firebase.apps.isEmpty
                                  ? Stream.value(const <dynamic>[])
                                  : NotificationService().watchNotifications(),
                              builder: (context, snapshot) {
                                final count = snapshot.data is List
                                    ? (snapshot.data as List)
                                          .where((item) => !item.isRead)
                                          .length
                                    : 0;
                                return _NotificationButton(
                                  count: count,
                                  onPressed: () =>
                                      NotificationCenterScreen.show(context),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CommunityHubScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.people_outline),
                              label: const Text('Közösség'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.surfaceContainer,
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                          ],
                        ),
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 4,
                          ),
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.primary
                                .withValues(alpha: .55),
                          ),
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                'HUNGARIAN HARDSTYLE',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Transform.translate(
                                  offset: const Offset(-38, 0),
                                  child: Transform.scale(
                                    scale: 1.28,
                                    alignment: Alignment.centerLeft,
                                    child: Image.asset(
                                      'assets/logos/huhs_logo.png',
                                      height: 96,
                                      width: double.infinity,
                                      alignment: Alignment.centerLeft,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'KICK  /  CULTURE  /  COMMUNITY',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            letterSpacing: 1.4,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'A magyar hardstyle otthona',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // A főoldali „hero" sorok (nyereményjáték, kérdőív, éves
                    // szavazás) UGYANAZT a format adjak a HomeActionCard-bol,
                    // ezert pontosan egyforma szelesseguek. A „Legfrissebb
                    // hírek" felirat csak ezutan jon, hogy a sorok ne a
                    // hírfolyam reszenek tűnjenek.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // A nyeremenyjatek sora magatol eltunik, ha nincs
                        // nyitott jatek es nincs frissen kihirdetett nyertes.
                        const PrizeEntryCard(),
                        // A kerdőív sora magatol eltunik, ha nincs nyitott
                        // kerdőív.
                        const PollEntryButton(),
                        ref
                            .watch(votingProvider)
                            .when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (season) => season.active || season.isClosed
                                  ? HomeActionCard(
                                      key: const Key('voting-entry'),
                                      eyebrow: 'SZAVAZÁS',
                                      label: season.hasPublishedResults
                                          ? 'Eredmények megtekintése'
                                          : season.isClosed
                                          ? 'A szavazás véget ért'
                                          : 'Szavazz a HUHS ${season.year} jelöltjeire',
                                      icon: Icons.how_to_vote_outlined,
                                      onTap: () {
                                        if (season.hasPublishedResults) {
                                          launchUrl(
                                            Uri.parse(season.resultsUrl),
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } else {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const VotingScreen(),
                                            ),
                                          );
                                        }
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Legfrissebb hírek',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    news.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: BrandLoadingIndicator()),
                      ),
                      error: (error, stack) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Text(
                              'Nem sikerült betölteni a híreket.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () {
                                ref.invalidate(newsProvider);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Újrapróbálás'),
                            ),
                          ],
                        ),
                      ),
                      data: (posts) {
                        final latestPosts = posts.take(5).toList();

                        if (latestPosts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'Nincs hír.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          // A „További hírek" sor ugyanazt a kártyaformat
                          // használja, mint a főoldali hero-sorok (kérdőív,
                          // nyereményjáték, szavazás), ezért a kereszttenegelyre
                          // kell igazítani: így tölti ki a teljes szélességet.
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _NewsSlider(posts: latestPosts),
                            const SizedBox(height: 16),
                            // A tulajdonos kérése: „a TOVÁBBI hírek gomb a
                            // főoldalon lehetne olyan mint a kérdőív meg a
                            // nyereményjáték kártya, egységesen".
                            HomeActionCard(
                              key: const Key('more-news'),
                              eyebrow: 'HÍREK',
                              label: 'További hírek',
                              icon: Icons.arrow_forward_rounded,
                              onTap: onShowMoreNews,
                            ),
                            activeGame.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (game) {
                                if (game != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: _ActiveGameCard(game: game),
                                  );
                                }
                                return latestGameResults.when(
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, _) => const SizedBox.shrink(),
                                  data: (resultsGame) => resultsGame == null
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          child: _ActiveGameCard(
                                            game: resultsGame,
                                            resultsOnly: true,
                                          ),
                                        ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 35),
                    Text(
                      'Közelgő események',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    events.when(
                      loading: () => const SizedBox(
                        height: 210,
                        child: Center(child: BrandLoadingIndicator()),
                      ),
                      error: (error, stack) => SizedBox(
                        height: 150,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Nem sikerült betölteni az eseményeket.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () {
                                ref.invalidate(eventsProvider);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Újrapróbálás'),
                            ),
                          ],
                        ),
                      ),
                      data: (items) {
                        final upcomingEvents = items.take(5).toList();

                        if (upcomingEvents.isEmpty) {
                          return const SizedBox(
                            height: 120,
                            child: Center(
                              child: Text(
                                'Nincs közelgő esemény.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          );
                        }

                        return SizedBox(
                          height: 380,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: upcomingEvents.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              return EventCard(
                                event: upcomingEvents[index],
                                width: 250,
                                height: 380,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    // Keep the home banner below the content, next to the
                    // persistent radio bar, instead of placing an ad above
                    // the HUHS header. It remains independent from the
                    // news/events futures and starts loading when the home
                    // screen is laid out.
                    const SizedBox(height: 24),
                    const Center(child: MobileAdBanner()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveGameCard extends StatelessWidget {
  const _ActiveGameCard({required this.game, this.resultsOnly = false});

  final HuhsGame game;
  final bool resultsOnly;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(game: game, resultsOnly: resultsOnly),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .65),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (game.artwork.isNotEmpty)
              Container(
                color: Colors.black,
                child: CachedNetworkImage(
                  imageUrl: game.artwork,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resultsOnly ? 'JÁTÉK EREDMÉNYEI' : 'JÁTÉK',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (game.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      game.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        resultsOnly
                            ? Icons.leaderboard_outlined
                            : Icons.play_circle_outline_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        resultsOnly
                            ? 'Eredménylista megnyitása'
                            : 'Játék megnyitása',
                      ),
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
}

class _NewsSlider extends StatefulWidget {
  final List<Post> posts;

  const _NewsSlider({required this.posts});

  @override
  State<_NewsSlider> createState() => _NewsSliderState();
}

class _NewsSliderState extends State<_NewsSlider> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.posts.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (!mounted || !_controller.hasClients) return;
        final nextPage = (_page + 1) % widget.posts.length;
        setState(() => _page = nextPage);
        _controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.clamp(0.0, 820.0);
        final cardHeight = (cardWidth * 9 / 16).clamp(250.0, 460.0);

        return Column(
          children: [
            SizedBox(
              height: cardHeight,
              child: Center(
                child: SizedBox(
                  width: cardWidth,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.posts.length,
                    onPageChanged: (page) {
                      if (mounted) setState(() => _page = page);
                    },
                    itemBuilder: (_, index) =>
                        FeaturedNewsCard(post: widget.posts[index]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.posts.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: index == _page ? 20 : 6,
                  decoration: BoxDecoration(
                    color: index == _page ? Colors.redAccent : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
