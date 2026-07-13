import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/events_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/event_card.dart';
import '../../widgets/featured_news_card.dart';
import '../../widgets/news_card.dart';
import '../../widgets/mobile_ad_banner.dart';

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
              ref.invalidate(newsProvider);
              ref.invalidate(eventsProvider);
              await ref.read(newsProvider.future);
              await ref.read(eventsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              children: [
                Center(
                  child: Transform.scale(
                    scale: 1.18,
                    child: Image.asset(
                      'assets/logos/huhs_logo.png',
                      width: width * 0.95,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(child: MobileAdBanner()),
                const SizedBox(height: 24),
                const Text(
                  'Legfrissebb hírek',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                news.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
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
                      children: [
                        FeaturedNewsCard(post: latestPosts.first),
                        const SizedBox(height: 18),
                        ...latestPosts
                            .skip(1)
                            .map((post) => NewsCard(post: post)),
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
                    child: Center(child: CircularProgressIndicator()),
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
                      // A műfaj-chipek több sorba törhetnek, ezért a kártyának
                      // elég helyet kell adnunk a tartalom levágása nélkül.
                      height: 420,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: upcomingEvents.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          return EventCard(
                            event: upcomingEvents[index],
                            width: 250,
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
