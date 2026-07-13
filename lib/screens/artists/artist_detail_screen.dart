import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/content/html_linkifier.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../models/artist.dart';
import '../../providers/artists_provider.dart';
import '../../widgets/event_card.dart';

class ArtistDetailScreen extends ConsumerWidget {
  final int artistId;
  final String fallbackName;

  const ArtistDetailScreen({
    super.key,
    required this.artistId,
    this.fallbackName = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (artistId <= 0) {
      return _MissingArtist(name: fallbackName);
    }

    final artist = ref.watch(artistDetailProvider(artistId));
    final title = artist.when(
      data: (value) => value.title.trim().isEmpty ? fallbackName : value.title,
      loading: () => fallbackName,
      error: (error, stack) => fallbackName,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title.trim().isEmpty ? 'DJ adatlap' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: artist.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fallbackName.isEmpty
                      ? 'Nem sikerült betölteni a DJ-adatlapot.'
                      : '$fallbackName adatlapját nem sikerült betölteni.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(artistDetailProvider(artistId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Újrapróbálás'),
                ),
              ],
            ),
          ),
        ),
        data: (value) => _ArtistContent(artist: value),
      ),
    );
  }
}

class _ArtistContent extends StatelessWidget {
  final Artist artist;

  const _ArtistContent({required this.artist});

  String _biographyHtml() {
    final value = artist.biography.trim();
    if (value.isEmpty) return '';

    final hasHtml = RegExp(
      r'</?[a-z][\s\S]*>',
      caseSensitive: false,
    ).hasMatch(value);
    if (hasHtml) return linkifyPlainUrls(value);

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
    final biography = _biographyHtml();
    final bookingEmail = artist.effectiveBookingEmail;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (artist.profileImageUrl.isNotEmpty)
              Hero(
                tag: 'artist_${artist.id}',
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: CachedNetworkImage(
                    imageUrl: artist.profileImageUrl,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.5),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (artist.realName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      artist.realName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 17,
                      ),
                    ),
                  ],
                  if (artist.location.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 7),
                        Expanded(child: Text(artist.location)),
                      ],
                    ),
                  ],
                  if (artist.categories.isNotEmpty || artist.genres.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...artist.categories.map(
                            (category) => Chip(label: Text(category.name)),
                          ),
                          ...artist.genres.map(
                            (genre) => Chip(
                              avatar: const Icon(Icons.graphic_eq, size: 17),
                              label: Text(genre),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (artist.socialLinks.isNotEmpty || artist.webUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ...artist.socialLinks.entries.map(
                            (entry) => OutlinedButton.icon(
                              onPressed: () =>
                                  openInAppBrowser(context, entry.value),
                              icon: Icon(_socialIcon(entry.key)),
                              label: Text(_socialLabel(entry.key)),
                            ),
                          ),
                          if (artist.webUrl.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  openInAppBrowser(context, artist.webUrl),
                              icon: const Icon(Icons.language),
                              label: const Text('Webes adatlap'),
                            ),
                        ],
                      ),
                    ),
                  if (bookingEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF171717),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fellépés kérése',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 7),
                            if (artist.bookingViaHuhs) ...[
                              const Text(
                                'A fellépés a Hungarian Hardstyle-on keresztül szervezhető.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                            ],
                            SelectableText(
                              bookingEmail,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => _openBookingEmail(context),
                              icon: const Icon(Icons.email_outlined),
                              label: Text(
                                artist.bookingViaHuhs
                                    ? 'Szervezés a HUHS-on keresztül'
                                    : 'Fellépés kérése e-mailben',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (biography.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Bemutatkozás',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Html(
                data: biography,
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
                    padding: HtmlPaddings.all(20),
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
            if (artist.upcomingEvents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Közelgő események',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...artist.upcomingEvents.map(
                      (event) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: EventCard(event: event),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 28),
          ],
        ),
      ),
    );
  }

  IconData _socialIcon(String key) {
    return switch (key) {
      'spotify' => Icons.music_note,
      'soundcloud' => Icons.cloud,
      'youtube' => Icons.play_circle_outline,
      'facebook' || 'instagram' || 'tiktok' => Icons.alternate_email,
      _ => Icons.link,
    };
  }

  Future<void> _openBookingEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: artist.effectiveBookingEmail,
      queryParameters: {'subject': 'Fellépés kérése – ${artist.title}'},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nem sikerült megnyitni a levelezőt.')),
      );
    }
  }

  String _socialLabel(String key) {
    return switch (key) {
      'facebook' => 'Facebook',
      'instagram' => 'Instagram',
      'tiktok' => 'TikTok',
      'spotify' => 'Spotify',
      'soundcloud' => 'SoundCloud',
      'youtube' => 'YouTube',
      _ => key,
    };
  }
}

class _MissingArtist extends StatelessWidget {
  final String name;

  const _MissingArtist({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DJ adatlap')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            name.isEmpty
                ? 'Ehhez a fellépőhöz még nincs összekapcsolt DJ-adatlap.'
                : '$name még nincs összekapcsolva egy DJ-adatlappal.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 17),
          ),
        ),
      ),
    );
  }
}
