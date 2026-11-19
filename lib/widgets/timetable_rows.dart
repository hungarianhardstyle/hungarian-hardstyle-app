import 'package:flutter/material.dart';

import '../models/event.dart';
import '../screens/artists/artist_detail_screen.dart';
import '../services/timetable_artists.dart';

/// Az időbeosztás sorai. Ahol a DJ az esemény fellépői között van, a sor
/// koppintásra a DJ adatlapjára visz; különben sima szöveg.
class TimetableRows extends StatelessWidget {
  const TimetableRows({
    super.key,
    required this.event,
    required this.entries,
    this.timeWidth = 96,
  });

  final HuhsEvent event;
  final List<EventTimetableEntry> entries;
  final double timeWidth;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries) _row(context, entry, primary),
      ],
    );
  }

  Widget _row(BuildContext context, EventTimetableEntry entry, Color primary) {
    final artistId = timetableArtistId(event, entry.artist);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timeWidth,
            child: Text(
              entry.time,
              style: TextStyle(color: primary, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(entry.artist)),
          if (artistId != null)
            Icon(Icons.chevron_right, size: 18, color: primary),
        ],
      ),
    );
    if (artistId == null) return content;
    return InkWell(
      key: ValueKey('timetable-artist-$artistId'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ArtistDetailScreen(
            artistId: artistId,
            fallbackName: entry.artist,
          ),
        ),
      ),
      child: content,
    );
  }
}
