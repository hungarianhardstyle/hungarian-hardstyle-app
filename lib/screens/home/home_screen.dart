import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/events_provider.dart';
import '../../providers/news_provider.dart';
import '../../models/post.dart';
import '../../widgets/event_card.dart';
import '../../widgets/featured_news_card.dart';
import '../../widgets/mobile_ad_banner.dart';
import '../../widgets/brand_loading_indicator.dart';
import '../community/community_screen.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback onShowMoreNews;

  const HomeScreen({super.key, required this.onShowMoreNews});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(newsProvider);
    final events = ref.watch(eventsProvider);
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(newsProvider);
            ref.invalidate(eventsProvider);
            await ref.read(newsProvider.future);
            await ref.read(eventsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CommunityAvatarButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CommunityProfileScreen(),
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF16090B), Color(0xFF2A080D)],
                  ),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x331F0005),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logos/huhs_logo.png',
                      width: width * 0.86,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'A magyar hardstyle otthona',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(height: 24),
              const Text(
                'Legfrissebb hírek',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
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
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      _NewsSlider(posts: latestPosts),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onShowMoreNews,
                          icon: const Icon(Icons.article_outlined),
                          label: const Text('További hírek'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 35),
              const Text(
                'Közelgő események',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
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
                          style: TextStyle(fontSize: 18, color: Colors.white70),
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
              const SizedBox(height: 24),
              const Center(child: MobileAdBanner()),
              const SizedBox(height: 30),
            ],
          ),
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
        _page = (_page + 1) % widget.posts.length;
        _controller.animateToPage(
          _page,
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
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.posts.length,
            onPageChanged: (page) => _page = page,
            itemBuilder: (_, index) =>
                FeaturedNewsCard(post: widget.posts[index]),
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
  }
}
