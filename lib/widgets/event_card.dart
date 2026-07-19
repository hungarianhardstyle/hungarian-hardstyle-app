import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/content/date_formatters.dart';
import '../models/event.dart';
import '../providers/favorites_provider.dart';
import '../screens/events/event_detail_screen.dart';
import 'favorite_button.dart';
import 'genre_chip.dart';

class EventCard extends StatelessWidget {
  final HuhsEvent event;
  final double? width;

  const EventCard({super.key, required this.event, this.width});

  List<String> _visibleGenres() {
    if (event.genres.length <= 4) {
      return event.genres;
    }

    return [
      ...event.genres.take(4),
      '+${event.genres.length - 4}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(event: event),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'event_${event.id}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: event.flyerUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: event.flyerUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey.shade900,
                            child: const Icon(
                              Icons.festival,
                              color: Colors.redAccent,
                              size: 54,
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    if (event.genres.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        // Chips scale with accessibility text size.
                        height: 48,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _visibleGenres()
                                .map(
                                  (genre) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: GenreChip(genre: genre),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (event.venueCity.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.venueCity,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade300),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formatEventDate(event.startDate, event.startTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        FavoriteButton(
                          kind: FavoriteKind.event,
                          id: event.id,
                          title: event.title,
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 15,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
