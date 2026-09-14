import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/content/date_formatters.dart';
import '../models/event.dart';
import '../screens/events/event_detail_screen.dart';
import 'genre_chip.dart';

class EventCard extends StatelessWidget {
  final HuhsEvent event;
  final double? width;
  final double? height;

  const EventCard({super.key, required this.event, this.width, this.height});

  List<String> _visibleGenres() {
    if (event.genres.length <= 4) {
      return event.genres;
    }

    return [...event.genres.take(4), '+${event.genres.length - 4}'];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageCacheWidth =
        ((width ?? MediaQuery.sizeOf(context).width) *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(360, 1600);
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
                    top: Radius.circular(8),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: event.flyerUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: event.flyerUrl,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            memCacheWidth: imageCacheWidth,
                            maxWidthDiskCache: imageCacheWidth,
                            color: colors.surfaceContainerHighest,
                            colorBlendMode: BlendMode.dstOver,
                          )
                        : Container(
                            color: Colors.grey.shade900,
                            child: Icon(
                              Icons.festival,
                              color: colors.primary,
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
                      style: TextStyle(
                        color: colors.onSurface,
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
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: colors.primary,
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
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formatEventDate(event.startDate, event.startTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 15,
                          color: colors.primary,
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
