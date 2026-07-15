import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content/html_linkifier.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../models/organizer.dart';
import '../../widgets/genre_chip.dart';
import '../../providers/organizers_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/event_card.dart';

class OrganizerDetailScreen extends ConsumerWidget {
  final int organizerId;
  final String fallbackName;

  const OrganizerDetailScreen({
    super.key,
    required this.organizerId,
    this.fallbackName = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (organizerId <= 0) {
      return _MissingOrganizer(name: fallbackName);
    }

    final organizer = ref.watch(organizerDetailProvider(organizerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Szervezői adatlap')),
      body: organizer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fallbackName.isEmpty
                      ? 'Nem sikerült betölteni a szervezői adatlapot.'
                      : '$fallbackName adatlapját nem sikerült betölteni.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(organizerDetailProvider(organizerId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Újrapróbálás'),
                ),
              ],
            ),
          ),
        ),
        data: (value) => _OrganizerContent(organizer: value),
      ),
    );
  }
}

class _OrganizerContent extends StatelessWidget {
  final OrganizerProfile organizer;

  const _OrganizerContent({required this.organizer});

  String _descriptionHtml() {
    final value = organizer.description.trim();
    if (value.isEmpty) return '';

    if (RegExp(r'</?[a-z][\s\S]*>', caseSensitive: false).hasMatch(value)) {
      return linkifyPlainUrls(value);
    }

    return linkifyPlainUrls(
      value
          .split(RegExp(r'\n\s*\n'))
          .map((paragraph) => '<p>${_escapeHtml(paragraph.trim())}</p>')
          .join(),
    );
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;')
        .replaceAll('\n', '<br>');
  }

  @override
  Widget build(BuildContext context) {
    final description = _descriptionHtml();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Hero(
                tag: 'organizer_${organizer.id}',
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  width: double.infinity,
                  height: 220,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: organizer.logoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: organizer.logoUrl,
                          fit: BoxFit.contain,
                        )
                      : const Icon(
                          Icons.groups,
                          size: 88,
                          color: Color(0xFFE53935),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              organizer.title,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, child) {
                final favorites = ref.watch(favoritesProvider);
                final isFavorite = favorites.contains(
                  FavoriteKind.organizer,
                  organizer.id,
                );
                return Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => ref.read(favoritesProvider).toggle(
                          FavoriteKind.organizer,
                          organizer.id,
                          organizer.title,
                        ),
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.redAccent,
                    ),
                    label: Text(isFavorite ? 'Kedvenc' : 'Kedvencekhez adom'),
                  ),
                );
              },
            ),
            if (organizer.location.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(organizer.location)),
                ],
              ),
            ],
            if (organizer.genres.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: organizer.genres
                      .map((genre) => GenreChip(genre: genre))
                      .toList(),
                ),
              ),
            if (organizer.socialLinks.isNotEmpty || organizer.webUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ...organizer.socialLinks.entries.map(
                      (entry) => OutlinedButton.icon(
                        onPressed: () => openSocialLink(
                          context,
                          entry.value,
                          title: _socialLabel(entry.key),
                        ),
                        icon: Icon(
                          entry.key == 'website'
                              ? Icons.language
                              : Icons.alternate_email,
                        ),
                        label: Text(_socialLabel(entry.key)),
                      ),
                    ),
                    if (organizer.webUrl.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () =>
                            openInAppBrowser(context, organizer.webUrl),
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Webes adatlap'),
                      ),
                  ],
                ),
              ),
            if (description.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 28, bottom: 4),
                child: Text(
                  'Bemutatkozás',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Html(
                data: description,
                onLinkTap: (url, attributes, element) => openInAppBrowser(
                  context,
                  resolveHtmlLinkTarget(
                    callbackUrl: url,
                    attributes: attributes,
                    visibleText: element?.text,
                  ),
                ),
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.symmetric(vertical: 16),
                    fontSize: FontSize(17),
                    lineHeight: const LineHeight(1.65),
                    color: Colors.white,
                  ),
                  'p': Style(margin: Margins.only(bottom: 16)),
                  'a': Style(
                    color: Colors.redAccent,
                    textDecoration: TextDecoration.none,
                  ),
                },
              ),
            ],
            if (organizer.upcomingEvents.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 24, bottom: 16),
                child: Text(
                  'Közelgő események',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              ...organizer.upcomingEvents.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: EventCard(event: event),
                ),
              ),
            ],
            SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 28),
          ],
        ),
      ),
    );
  }

  String _socialLabel(String key) {
    return switch (key) {
      'website' => 'Weboldal',
      'facebook' => 'Facebook',
      'instagram' => 'Instagram',
      'tiktok' => 'TikTok',
      _ => key,
    };
  }
}

class _MissingOrganizer extends StatelessWidget {
  final String name;

  const _MissingOrganizer({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szervezői adatlap')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            name.isEmpty
                ? 'Ehhez a szervezőhöz még nincs összekapcsolt adatlap.'
                : '$name még nincs összekapcsolva egy szervezői adatlappal.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 17),
          ),
        ),
      ),
    );
  }
}
