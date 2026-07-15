import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/content/html_linkifier.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../models/event.dart';
import '../artists/artist_detail_screen.dart';
import '../organizers/organizer_detail_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final HuhsEvent event;

  const EventDetailScreen({super.key, required this.event});

  String _formatDate() {
    try {
      final parsed = DateTime.parse(event.startDate);
      final date = DateFormat('yyyy. MMMM d.', 'hu_HU').format(parsed);

      if (event.startTime.isEmpty) {
        return date;
      }

      return '$date - ${event.startTime}';
    } catch (_) {
      if (event.startTime.isEmpty) {
        return event.startDate;
      }

      return '${event.startDate} - ${event.startTime}';
    }
  }

  Future<void> _openExternalUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      _showOpenError(context);
      return;
    }

    var opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {}
    if (!opened) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!opened && context.mounted) {
      _showOpenError(context);
    }
  }

  void _showOpenError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nem sikerult megnyitni a linket.')),
    );
  }

  String _descriptionHtml() {
    final description = _restorePlainTextBreaks(event.description.trim());

    if (description.isEmpty) {
      return '';
    }

    final hasHtml = RegExp(
      r'</?[a-z][\s\S]*>',
      caseSensitive: false,
    ).hasMatch(description);

    if (hasHtml) {
      return description;
    }

    return description
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) {
          final lines = paragraph
              .split(RegExp(r'\n+'))
              .map((line) => _escapeHtml(line.trim()))
              .where((line) => line.isNotEmpty)
              .toList();

          if (lines.isEmpty) {
            return '';
          }

          return '<p>${lines.join('<br>')}</p>';
        })
        .where((paragraph) => paragraph.isNotEmpty)
        .join();
  }

  String _restorePlainTextBreaks(String value) {
    if (RegExp(r'</?[a-z][\s\S]*>', caseSensitive: false).hasMatch(value)) {
      return value;
    }

    return value
        .replaceAllMapped(
          RegExp(r'([a-záéíóöőúüű])([A-ZÁÉÍÓÖŐÚÜŰ])'),
          (match) => '${match.group(1)}\n${match.group(2)}',
        )
        .replaceAllMapped(
          RegExp(r'([.!?])([A-ZÁÉÍÓÖŐÚÜŰ])'),
          (match) => '${match.group(1)}\n${match.group(2)}',
        );
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  @override
  Widget build(BuildContext context) {
    final descriptionHtml = _descriptionHtml();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          event.title.trim().isEmpty ? 'Esemény' : event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.flyerUrl.isNotEmpty)
              Hero(
                tag: 'event_${event.id}',
                child: CachedNetworkImage(
                  imageUrl: event.flyerUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  if (event.genres.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: event.genres
                          .map(
                            (genre) => Chip(
                              label: Text(genre),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.calendar_today, text: _formatDate()),
                  if (event.venueLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: event.venueLine,
                    ),
                  ],
                  if (event.organizer.name.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.groups_outlined,
                      text: event.organizer.name,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrganizerDetailScreen(
                            organizerId: event.organizer.id,
                            fallbackName: event.organizer.name,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (event.artists.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ArtistLinks(artists: event.artists),
                  ],
                  if (event.hasTicket ||
                      event.hasGoogleMaps ||
                      event.hasFacebookEvent) ...[
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (event.hasFacebookEvent)
                          FilledButton.icon(
                            onPressed: () => openSocialLink(
                              context,
                              event.facebookEventUrl,
                              title: 'Facebook',
                            ),
                            icon: const Icon(Icons.facebook),
                            label: const Text('Facebook'),
                          ),
                        if (event.hasTicket)
                          FilledButton.icon(
                            onPressed: () =>
                                openInAppBrowser(context, event.ticketUrl),
                            icon: const Icon(Icons.confirmation_number),
                            label: const Text('Jegyvásárlás'),
                          ),
                        if (event.hasGoogleMaps)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openExternalUrl(context, event.googleMapsUrl),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Térkép'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (descriptionHtml.isNotEmpty)
              Html(
                data: linkifyPlainUrls(descriptionHtml),
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
                    fontSize: FontSize(18),
                    lineHeight: const LineHeight(1.7),
                    color: Colors.white,
                  ),
                  'p': Style(margin: Margins.only(bottom: 18)),
                  'br': Style(margin: Margins.only(bottom: 6)),
                  'h2': Style(
                    margin: Margins.only(top: 12, bottom: 12),
                    fontSize: FontSize(24),
                    fontWeight: FontWeight.bold,
                  ),
                  'h3': Style(
                    margin: Margins.only(top: 10, bottom: 10),
                    fontSize: FontSize(21),
                    fontWeight: FontWeight.bold,
                  ),
                  'ul': Style(margin: Margins.only(bottom: 18)),
                  'ol': Style(margin: Margins.only(bottom: 18)),
                  'li': Style(margin: Margins.only(bottom: 8)),
                  'strong': Style(fontWeight: FontWeight.bold),
                  'a': Style(
                    color: Colors.redAccent,
                    textDecoration: TextDecoration.none,
                  ),
                },
              )
            else
              const SizedBox(height: 24),
            SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 24),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.redAccent),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                text,
                style: TextStyle(
                  color: onTap == null
                      ? Colors.grey.shade300
                      : Colors.redAccent,
                  height: 1.35,
                  decoration: onTap == null ? null : TextDecoration.underline,
                  decorationColor: Colors.redAccent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistLinks extends StatelessWidget {
  final List<EventArtist> artists;

  const _ArtistLinks({required this.artists});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.music_note_outlined,
          size: 20,
          color: Colors.redAccent,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: artists
                .map(
                  (artist) => InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtistDetailScreen(
                          artistId: artist.id,
                          fallbackName: artist.name,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        artist.name,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          height: 1.35,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
