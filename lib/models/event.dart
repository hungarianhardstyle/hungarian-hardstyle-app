class EventArtist {
  final int id;
  final String name;

  const EventArtist({required this.id, required this.name});

  factory EventArtist.fromJson(Object? value) {
    if (value is String) {
      return EventArtist(id: 0, name: value);
    }

    if (value is Map<String, dynamic>) {
      return EventArtist(
        id: _readInt(value['id']),
        name: _readString(value['name'] ?? value['title']),
      );
    }

    return const EventArtist(id: 0, name: '');
  }
}

class EventOrganizer {
  final int id;
  final String name;

  const EventOrganizer({required this.id, required this.name});

  factory EventOrganizer.fromJson(Object? value) {
    if (value is String) {
      return EventOrganizer(id: 0, name: _decodeHtmlText(value));
    }

    if (value is Map<String, dynamic>) {
      return EventOrganizer(
        id: _readInt(value['id']),
        name: _readString(value['name'] ?? value['title']),
      );
    }

    return const EventOrganizer(id: 0, name: '');
  }
}

class HuhsEvent {
  final int id;
  final String title;
  final String description;
  final String startDate;
  final String startTime;
  final String endDate;
  final String endTime;
  final String venueName;
  final String venueCity;
  final String venueZip;
  final String venueAddress;
  final String venueCountry;
  final String googleMapsUrl;
  final String ticketType;
  final String ticketUrl;
  final EventOrganizer organizer;
  final List<EventArtist> artists;
  final String flyerUrl;
  final bool featured;
  final bool visible;
  final String status;

  const HuhsEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.venueName,
    required this.venueCity,
    required this.venueZip,
    required this.venueAddress,
    required this.venueCountry,
    required this.googleMapsUrl,
    required this.ticketType,
    required this.ticketUrl,
    required this.organizer,
    required this.artists,
    required this.flyerUrl,
    required this.featured,
    required this.visible,
    required this.status,
  });

  factory HuhsEvent.fromJson(Map<String, dynamic> json) {
    final artistValues = json['artists'];

    return HuhsEvent(
      id: _readInt(json['id']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      startDate: _readString(json['start_date']),
      startTime: _readString(json['start_time']),
      endDate: _readString(json['end_date']),
      endTime: _readString(json['end_time']),
      venueName: _readString(json['venue_name']),
      venueCity: _readString(json['venue_city']),
      venueZip: _readString(json['venue_zip']),
      venueAddress: _readString(json['venue_address']),
      venueCountry: _readString(json['venue_country']),
      googleMapsUrl: _readString(json['google_maps']),
      ticketType: _readString(json['ticket_type']),
      ticketUrl: _readString(json['ticket_url']),
      organizer: EventOrganizer.fromJson(json['organizer']),
      artists: artistValues is List<dynamic>
          ? artistValues
                .map(EventArtist.fromJson)
                .where((artist) => artist.name.isNotEmpty)
                .toList()
          : const [],
      flyerUrl: _readImageUrl(json['flyer']),
      featured: _readBool(json['featured']),
      visible: _readBool(json['visible']),
      status: _readString(json['status']),
    );
  }

  String get venueLine {
    final parts = [
      venueName,
      venueZip,
      venueCity,
      venueAddress,
    ].where((part) => part.trim().isNotEmpty).toList();

    return parts.join(', ');
  }

  bool get hasTicket => ticketUrl.trim().isNotEmpty;

  bool get hasGoogleMaps => googleMapsUrl.trim().isNotEmpty;
}

String _readString(Object? value) {
  if (value is String) {
    return _decodeHtmlText(value);
  }

  if (value is num || value is bool) {
    return value.toString();
  }

  return '';
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    final normalized = value.toLowerCase().trim();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  return false;
}

String _readImageUrl(Object? value) {
  if (value is String) {
    return value;
  }

  if (value is Map<String, dynamic>) {
    return _readString(
      value['url'] ??
          value['source_url'] ??
          value['full'] ??
          value['medium'] ??
          value['thumbnail'],
    );
  }

  return '';
}

String _decodeHtmlText(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
        final codePoint = int.tryParse(match.group(1)!, radix: 16);
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      })
      .replaceAllMapped(RegExp(r'&#([0-9]+);'), (match) {
        final codePoint = int.tryParse(match.group(1)!);
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      });
}
