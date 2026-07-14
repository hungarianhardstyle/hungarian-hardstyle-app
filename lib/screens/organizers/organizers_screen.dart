import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/organizer.dart';
import '../../providers/organizers_provider.dart';
import 'organizer_detail_screen.dart';

class OrganizersScreen extends ConsumerStatefulWidget {
  const OrganizersScreen({super.key});

  @override
  ConsumerState<OrganizersScreen> createState() => _OrganizersScreenState();
}

class _OrganizersScreenState extends ConsumerState<OrganizersScreen> {
  String _search = '';
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _search = value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final organizers = ref.watch(organizersProvider(_search));

    return Scaffold(
      appBar: AppBar(title: const Text('Szervezők')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(organizersProvider(_search).future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Szervezők',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Keresés szervezők között…',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: const Color(0xFF171717),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...organizers.when(
                  loading: () => const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (error, stack) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _OrganizerError(
                        onRetry: () =>
                            ref.invalidate(organizersProvider(_search)),
                      ),
                    ),
                  ],
                  data: (page) {
                    if (page.items.isEmpty) {
                      return const [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'Nincs találat.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ];
                    }

                    return [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                        sliver: SliverList.separated(
                          itemCount: page.items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) =>
                              _OrganizerCard(organizer: page.items[index]),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  final OrganizerProfile organizer;

  const _OrganizerCard({required this.organizer});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => OrganizerDetailScreen(
              organizerId: organizer.id,
              fallbackName: organizer.title,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Hero(
                tag: 'organizer_${organizer.id}',
                child: Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: organizer.logoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: organizer.logoUrl,
                          fit: BoxFit.contain,
                        )
                      : const Icon(
                          Icons.groups,
                          size: 46,
                          color: Color(0xFFE53935),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            organizer.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (organizer.featured)
                          const Icon(
                            Icons.star,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      organizer.location.isEmpty
                          ? 'Szervezői adatlap'
                          : organizer.location,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (organizer.genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        organizer.genres.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizerError extends StatelessWidget {
  final VoidCallback onRetry;

  const _OrganizerError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Nem sikerült betölteni a szervezőket.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Újrapróbálás'),
          ),
        ],
      ),
    );
  }
}
