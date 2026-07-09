import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/event.dart';

class EventDetailScreen extends StatelessWidget {
  final HuhsEvent event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

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

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      _showOpenError(context);
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      _showOpenError(context);
    }
  }

  void _showOpenError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nem sikerult megnyitni a linket.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artists = event.artists.map((artist) => artist.name).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Esemény'),
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
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    text: _formatDate(),
                  ),
                  if (event.venueLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: event.venueLine,
                    ),
                  ],
                  if (event.organizer.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.groups_outlined,
                      text: event.organizer,
                    ),
                  ],
                  if (artists.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.music_note_outlined,
                      text: artists,
                    ),
                  ],
                  if (event.hasTicket || event.hasGoogleMaps) ...[
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        if (event.hasTicket)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _openUrl(
                                context,
                                event.ticketUrl,
                              ),
                              icon: const Icon(Icons.confirmation_number),
                              label: const Text('Jegyek'),
                            ),
                          ),
                        if (event.hasTicket && event.hasGoogleMaps)
                          const SizedBox(width: 12),
                        if (event.hasGoogleMaps)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openUrl(
                                context,
                                event.googleMapsUrl,
                              ),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Térkép'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (event.description.isNotEmpty)
              Html(
                data: event.description,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.all(20),
                    fontSize: FontSize(18),
                    lineHeight: const LineHeight(1.7),
                    color: Colors.white,
                  ),
                  'p': Style(
                    margin: Margins.only(bottom: 18),
                  ),
                  'a': Style(
                    color: Colors.redAccent,
                    textDecoration: TextDecoration.none,
                  ),
                },
              )
            else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.redAccent,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade300,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
